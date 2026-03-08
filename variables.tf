variable "proxmox_root_password" {
  description = "Root SSH password for the Proxmox host"
  type        = string
  sensitive   = true
}

variable "proxmox_host" {
  description = "Hostname or IP of the Proxmox server (used for SSH)"
  type        = string
  default     = "proxmox.dunkurjunk.net"
}

variable "proxmox_node" {
  description = "Proxmox node name (as shown in the UI and used in pvesh paths)"
  type        = string
  default     = "prox"
}

variable "domain" {
  description = "Base domain name managed via Cloudflare (e.g. dunkurjunk.net)"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit + Zone read permissions (for ACME DNS-01 challenge)"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "acme_email" {
  description = "Email address for Let's Encrypt registration"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to inject into cloud-init VMs"
  type        = string
}