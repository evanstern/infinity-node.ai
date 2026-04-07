variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL, including port 8006"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in user@realm!token=value format"
  type        = string
  sensitive   = true
}

variable "gateway" {
  description = "Default gateway for the 192.168.1.0/24 network"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key injected into each VM"
  type        = string
  sensitive   = true
}

variable "vm_username" {
  description = "Username created on each VM via cloud-init"
  type        = string
  default     = "coda"
}

variable "vm_password" {
  description = "Password for the VM user created via cloud-init"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API"
  type        = bool
  default     = true
}
