# Main OpenTofu configuration for Proxmox homelab

module "proxmox_system" {
  source = "./modules/proxmox_system"

  proxmox_root_password = var.proxmox_root_password
  proxmox_host          = var.proxmox_host
  proxmox_node          = var.proxmox_node
  domain                = var.domain
  cloudflare_api_token  = var.cloudflare_api_token
  acme_email            = var.acme_email
}
