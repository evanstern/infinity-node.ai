# terraform/modules/proxmox-vm/outputs.tf

output "vm_id" {
  description = "The Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "ip_address" {
  description = "The VM's IP address"
  value       = var.ip_address
}

output "name" {
  description = "The VM hostname"
  value       = proxmox_virtual_environment_vm.vm.name
}
