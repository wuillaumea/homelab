# homelab

Declarative homelab configuration managed with [OpenTofu](https://opentofu.org/).

## Infrastructure

| Host | URL | Managed via |
|------|-----|-------------|
| Proxmox VE | `https://proxmox.<domain>` (443 via nginx) or `https://prox.local:8006` (direct) | `telmate/proxmox` |

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) installed in WSL
- SSH access to the Proxmox host as `root`
- A Proxmox service account with the `TerraformProv` role (see [Setup](#proxmox-setup))
- A domain managed by [Cloudflare](https://dash.cloudflare.com/) (for DNS-01 ACME certificates)

## Proxmox Setup

A dedicated service account is used instead of `root`. Run the following on the Proxmox host once:

```sh
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Pool.Audit Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

## Cloudflare Setup

A Cloudflare API token is used for the ACME DNS-01 challenge to obtain Let's Encrypt wildcard certificates. No public DNS records are created — the token is only used to prove domain ownership.

1. Go to [Cloudflare Dashboard → API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Create a token with these permissions:
   - **Zone → DNS → Edit**
   - **Zone → Zone → Read**
3. Scope it to the zone for your domain

The ACME provider creates a temporary `_acme-challenge` TXT record, Let's Encrypt validates it, and the record is removed. Your local DNS server handles the actual `proxmox.<domain>` → LAN IP resolution.

## Configuration

Copy `.env.example` to `.env` and fill in your credentials:

```sh
cp .env.example .env
```

```sh
# .env
export PM_USER="terraform-prov@pve"
export PM_PASS="<terraform user password>"
export TF_VAR_proxmox_root_password="<root SSH password>"
export TF_VAR_proxmox_host="<proxmox IP>"
export TF_VAR_proxmox_node="prox"
export TF_VAR_domain="<your-domain.net>"
export TF_VAR_cloudflare_api_token="<cloudflare API token>"
export TF_VAR_cloudflare_zone_id="<cloudflare zone ID>"
export TF_VAR_acme_email="<your email>"
```

Credentials are read from environment variables — `.env` is git-ignored and never committed.

## Usage

All commands must be run from WSL with `.env` sourced:

```sh
source .env

tofu init     # first time only
tofu plan
tofu apply
```

## State

State is stored locally at `/mnt/homelab/terraform.tfstate` (WSL path). Make sure this directory exists:

```sh
mkdir -p /mnt/homelab
```

## Project Structure

```
homelab/
├── main.tf                          # Module calls
├── providers.tf                     # Provider config + backend
├── variables.tf                     # Root-level variables
└── modules/
    └── proxmox_system/
        ├── main.tf                  # System config (DNS, nag patch, nginx)
        ├── cert.tf                  # ACME wildcard cert + deployment
        ├── variables.tf             # Module inputs
        └── templates/
            └── nginx-proxmox.conf.tpl  # nginx reverse proxy template
```

## What's Managed

| Resource | Module | Description |
|----------|--------|-------------|
| DNS config | `proxmox_system` | Sets the node's DNS resolvers via `pvesh` (router + 8.8.8.8 fallback) |
| Subscription nag | `proxmox_system` | Patches the Proxmox web UI to suppress the no-subscription popup |
| nginx reverse proxy | `proxmox_system` | Installs nginx; port 443 proxies to pveproxy on 8006, port 80 redirects to HTTPS |
| Wildcard TLS cert | `proxmox_system` | Let's Encrypt wildcard cert (`*.<domain>`) via Cloudflare DNS-01 challenge |
| Cert deployment | `proxmox_system` | Deploys cert + key to Proxmox and reloads nginx; auto-renews when < 30 days remain |
