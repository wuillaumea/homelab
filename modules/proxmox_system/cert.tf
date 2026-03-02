# -----------------------------------------------------------------
# ACME / Let's Encrypt wildcard cert for *.domain
# Uses Cloudflare DNS-01 challenge — no public A record needed.
# Your local DNS server handles resolution separately.
# -----------------------------------------------------------------

resource "tls_private_key" "acme_account" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.acme_account.private_key_pem
  email_address   = var.acme_email
}

resource "acme_certificate" "wildcard" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "*.${var.domain}"

  dns_challenge {
    provider = "cloudflare"
    config = {
      CF_DNS_API_TOKEN       = var.cloudflare_api_token
      CF_POLLING_INTERVAL    = "10"
      CF_PROPAGATION_TIMEOUT = "300"
    }
  }

  # Use public DNS for propagation checks
  recursive_nameservers = ["1.1.1.1:53", "8.8.8.8:53"]

  # Re-issue when within 30 days of expiry on next apply
  min_days_remaining = 30
}

# -----------------------------------------------------------------
# Deploy cert + key to Proxmox and reload nginx
# -----------------------------------------------------------------
resource "null_resource" "deploy_proxmox_cert" {
  depends_on = [null_resource.nginx_proxy]

  triggers = {
    cert_pem = acme_certificate.wildcard.certificate_pem
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = var.proxmox_root_password
    host     = var.proxmox_host
  }

  provisioner "file" {
    content     = acme_certificate.wildcard.private_key_pem
    destination = "/etc/ssl/private/proxmox-acme.key"
  }

  provisioner "file" {
    content     = "${acme_certificate.wildcard.certificate_pem}${acme_certificate.wildcard.issuer_pem}"
    destination = "/etc/ssl/certs/proxmox-acme.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /etc/ssl/private/proxmox-acme.key",
      "chmod 644 /etc/ssl/certs/proxmox-acme.pem",
      "nginx -t && systemctl reload nginx",
    ]
  }
}
