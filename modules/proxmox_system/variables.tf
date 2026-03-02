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
  description = "Proxmox node name (as shown in the UI and used in pvesh paths)"
  type        = string
}

variable "domain" {
  description = "Base domain name (e.g. dunkurjunk.net)"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit + Zone read permissions"
  type        = string
  sensitive   = true
}

variable "acme_email" {
  description = "Email address for Let's Encrypt registration"
  type        = string
}
