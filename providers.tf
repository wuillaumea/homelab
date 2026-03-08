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
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "local" {
    path = "/mnt/homelab/terraform.tfstate"
  }
}

provider "proxmox" {
  pm_api_url      = "https://${var.proxmox_host}:8006/api2/json"
  pm_tls_insecure = true
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
