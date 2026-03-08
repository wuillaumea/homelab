variable "proxmox_root_password" {
  description = "Root SSH password for the Proxmox host"
  type        = string
  sensitive   = true
}

variable "proxmox_host" {
  description = "Hostname or IP of the Proxmox server (used for SSH)"
  type        = string
}

variable "proxmox_node" {
  description = "Proxmox node name (as shown in the UI)"
  type        = string
}

variable "vm_name" {
  description = "Name of the Docker VM"
  type        = string
  default     = "docker"
}

variable "vm_id" {
  description = "Proxmox VM ID for the Docker VM (0 = auto-assign)"
  type        = number
  default     = 0
}

variable "template_vm_id" {
  description = "Proxmox VM ID for the cloud-init template"
  type        = number
  default     = 9000
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 4096
}

variable "disk_size" {
  description = "Boot disk size (e.g. 32G)"
  type        = string
  default     = "32G"
}

variable "storage_pool" {
  description = "Proxmox storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "Static IP in CIDR notation (e.g. 192.168.1.50/24), or 'dhcp'"
  type        = string
  default     = "dhcp"
}

variable "gateway" {
  description = "Default gateway IP (required when using a static IP)"
  type        = string
  default     = ""
}

variable "nameserver" {
  description = "DNS server for the VM"
  type        = string
  default     = "192.168.1.1"
}

variable "ssh_public_key" {
  description = "SSH public key to inject via cloud-init for the default user"
  type        = string
}

variable "ci_user" {
  description = "Default user created by cloud-init"
  type        = string
  default     = "alex"
}

variable "ubuntu_version" {
  description = "Ubuntu version to use for the cloud image (e.g. 24.04)"
  type        = string
  default     = "24.04"
}

variable "onboot" {
  description = "Start the VM automatically when the Proxmox host boots"
  type        = bool
  default     = true
}
