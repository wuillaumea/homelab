output "vm_id" {
  description = "Proxmox VM ID of the Docker VM"
  value       = proxmox_vm_qemu.docker.vmid
}

output "vm_name" {
  description = "Name of the Docker VM"
  value       = proxmox_vm_qemu.docker.name
}

output "default_ipv4_address" {
  description = "Primary IPv4 address reported by the QEMU guest agent"
  value       = proxmox_vm_qemu.docker.default_ipv4_address
}

output "ssh_command" {
  description = "Convenient SSH command to connect to the Docker VM"
  value       = "ssh ${var.ci_user}@${proxmox_vm_qemu.docker.default_ipv4_address}"
}
