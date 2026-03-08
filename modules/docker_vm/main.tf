terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Cloud-init template — download Ubuntu cloud image & create a Proxmox
# VM template if one doesn't already exist.
# ---------------------------------------------------------------------------

locals {
  ubuntu_img_url = "https://cloud-images.ubuntu.com/releases/${var.ubuntu_version}/release/ubuntu-${var.ubuntu_version}-server-cloudimg-amd64.img"
  template_name  = "ubuntu-${replace(var.ubuntu_version, ".", "")}-cloud"

  cloud_init_config = templatefile("${path.module}/templates/cloud-init-docker.yaml.tpl", {
    ci_user = var.ci_user
  })
}

resource "null_resource" "cloud_image_template" {
  triggers = {
    template_id = var.template_vm_id
    version     = var.ubuntu_version
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = var.proxmox_root_password
    host     = var.proxmox_host
  }

  provisioner "remote-exec" {
    inline = [
      # Skip everything if the template already exists
      "qm status ${var.template_vm_id} >/dev/null 2>&1 && echo 'Template already exists, skipping.' && exit 0",

      # Download the Ubuntu cloud image
      "wget -q -O /tmp/${local.template_name}.img '${local.ubuntu_img_url}'",

      # Create the VM that will become our template
      "qm create ${var.template_vm_id} --name '${local.template_name}' --ostype l26 --memory 2048 --cores 2 --cpu host --net0 virtio,bridge=${var.network_bridge}",

      # Import the cloud image as the boot disk
      "qm importdisk ${var.template_vm_id} /tmp/${local.template_name}.img ${var.storage_pool}",

      # Attach the imported disk as scsi0 with discard and SSD emulation
      "qm set ${var.template_vm_id} --scsihw virtio-scsi-single --scsi0 ${var.storage_pool}:vm-${var.template_vm_id}-disk-0,discard=on,ssd=1",

      # Add a cloud-init drive
      "qm set ${var.template_vm_id} --ide2 ${var.storage_pool}:cloudinit",

      # Set boot order to scsi0
      "qm set ${var.template_vm_id} --boot order=scsi0",

      # Enable the serial console (required for cloud-init on some images)
      "qm set ${var.template_vm_id} --serial0 socket --vga serial0",

      # Enable the QEMU guest agent
      "qm set ${var.template_vm_id} --agent enabled=1",

      # Convert to template
      "qm template ${var.template_vm_id}",

      # Clean up
      "rm -f /tmp/${local.template_name}.img",
    ]
  }
}

# ---------------------------------------------------------------------------
# Upload cloud-init snippet BEFORE creating the VM so cicustom can reference it
# ---------------------------------------------------------------------------

resource "null_resource" "cloud_init_snippet" {
  depends_on = [null_resource.cloud_image_template]

  triggers = {
    config_hash = md5(local.cloud_init_config)
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = var.proxmox_root_password
    host     = var.proxmox_host
  }

  provisioner "remote-exec" {
    inline = [
      # Ensure the snippets path is a directory (remove if it's a stale file)
      "test -f /var/lib/vz/snippets && rm -f /var/lib/vz/snippets; mkdir -p /var/lib/vz/snippets",

      # Enable the 'snippets' content type on 'local' storage if not already present
      "if ! grep -A5 '^dir: local' /etc/pve/storage.cfg | grep -q snippets; then CURRENT=$(grep -A5 '^dir: local' /etc/pve/storage.cfg | grep content | sed 's/.*content //'); pvesm set local --content \"$${CURRENT},snippets\"; fi",
    ]
  }

  provisioner "file" {
    content     = local.cloud_init_config
    destination = "/var/lib/vz/snippets/${var.vm_name}-cloud-init.yaml"
  }
}

# ---------------------------------------------------------------------------
# Docker VM — full clone from the cloud-init template
# ---------------------------------------------------------------------------

resource "proxmox_vm_qemu" "docker" {
  depends_on = [null_resource.cloud_init_snippet]

  name        = var.vm_name
  vmid        = var.vm_id != 0 ? var.vm_id : null
  target_node = var.proxmox_node
  clone       = local.template_name
  full_clone  = true
  agent              = 1
  start_at_node_boot = var.onboot
  memory      = var.memory
  scsihw      = "virtio-scsi-single"

  cpu {
    type  = "host"
    cores = var.cores
  }

  # Boot disk
  disks {
    scsi {
      scsi0 {
        disk {
          size    = var.disk_size
          storage = var.storage_pool
          discard = true
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = var.storage_pool
        }
      }
    }
  }

  # Network
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-init settings
  os_type    = "cloud-init"
  cicustom   = "user=local:snippets/${var.vm_name}-cloud-init.yaml"
  ciuser     = var.ci_user
  sshkeys    = var.ssh_public_key
  nameserver = var.nameserver
  ipconfig0  = var.ip_address == "dhcp" ? "ip=dhcp" : "ip=${var.ip_address},gw=${var.gateway}"

  # Ignore changes to the cloud-init drive after first boot
  lifecycle {
    ignore_changes = [
      cicustom,
      ciuser,
      sshkeys,
      nameserver,
      ipconfig0,
    ]
  }
}
