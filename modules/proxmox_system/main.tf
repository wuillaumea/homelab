terraform {
  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

locals {
  nginx_conf = templatefile("${path.module}/templates/nginx-proxmox.conf.tpl", {
    domain = var.domain
  })
  nginx_conf_hash = md5(local.nginx_conf)
}

# Patches the Proxmox web UI to remove the subscription nag popup.
# The sed command finds the active-subscription check in the widget toolkit JS
# and replaces it with `false` so the popup never triggers.
# pveproxy is restarted to serve the updated file immediately.
resource "null_resource" "disable_subscription_nag" {
  connection {
    type     = "ssh"
    user     = "root"
    password = var.proxmox_root_password
    host     = var.proxmox_host
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i.bak \"s/res\\.data\\.status\\.toLowerCase() !== 'active'/false/\" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js",
      "systemctl restart pveproxy"
    ]
  }
}

# Fixes DNS on the Proxmox node. By default the node may point to 127.0.0.1
# with no local resolver running, causing all apt installs to fail.
# Uses pvesh to set DNS via the Proxmox API so the setting survives reboots.
resource "null_resource" "proxmox_dns" {
  connection {
    type     = "ssh"
    user     = "root"
    password = var.proxmox_root_password
    host     = var.proxmox_host
  }

  provisioner "remote-exec" {
    inline = [
      # Write resolv.conf directly first so DNS (and pvesh itself) can work
      "printf 'search local\\nnameserver 192.168.1.1\\nnameserver 8.8.8.8\\n' > /etc/resolv.conf",
      # Now persist the config properly via Proxmox's own API
      "pvesh set /nodes/${var.proxmox_node}/dns --dns1 192.168.1.1 --dns2 8.8.8.8 --search local",
    ]
  }
}

# Installs nginx as a reverse proxy so Proxmox is accessible on port 443.
# HTTP (port 80) redirects to HTTPS. A placeholder self-signed cert is
# created if the real ACME cert doesn't exist yet so nginx can start.
# The systemd override ensures nginx starts after pve-cluster so the
# /etc/pve filesystem is available.
resource "null_resource" "nginx_proxy" {
  depends_on = [null_resource.proxmox_dns]

  triggers = {
    conf_hash = local.nginx_conf_hash
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = var.proxmox_root_password
    host     = var.proxmox_host
  }

  provisioner "remote-exec" {
    inline = [
      # Disable enterprise repo (requires subscription) and enable no-subscription repo
      "echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' > /etc/apt/sources.list.d/pve-no-subscription.list",
      "sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true",
      "apt-get update -qq",
      "apt-get install -y nginx",
    ]
  }

  provisioner "file" {
    content     = local.nginx_conf
    destination = "/etc/nginx/conf.d/proxmox.conf"
  }

  provisioner "remote-exec" {
    inline = [
      # Remove default site configs that would conflict on port 80/443
      "rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf",
      # Create a placeholder self-signed cert so nginx can start before the real ACME cert is deployed
      "test -f /etc/ssl/certs/proxmox-acme.pem || openssl req -x509 -newkey rsa:2048 -keyout /etc/ssl/private/proxmox-acme.key -out /etc/ssl/certs/proxmox-acme.pem -days 1 -nodes -subj '/CN=proxmox.${var.domain}'",
      # Systemd override: only start nginx after pve-cluster (certs are on /etc/pve)
      "mkdir -p /etc/systemd/system/nginx.service.d",
      "printf '[Unit]\\nRequires=pve-cluster.service\\nAfter=pve-cluster.service\\n' > /etc/systemd/system/nginx.service.d/override.conf",
      "systemctl daemon-reload",
      "nginx -t",
      "systemctl enable nginx",
      "systemctl restart nginx",
    ]
  }
}
