# terraform/modules/proxmox-vm/variables.tf

variable "vm_id" {
  description = "Unique VM ID in Proxmox (100-999999)"
  type        = number
}

variable "name" {
  description = "VM hostname"
  type        = string
}

variable "node_name" {
  description = "Proxmox node name to create the VM on"
  type        = string
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "RAM in megabytes"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Boot disk size in GiB"
  type        = number
  default     = 32
}

variable "datastore_id" {
  description = "Proxmox storage ID for VM disk"
  type        = string
  default     = "local-zfs"
}

variable "disk_file_format" {
  description = "Disk image format. Use 'raw' for LVM/ZFS, 'qcow2' for directory-based storage"
  type        = string
  default     = "raw"
}

variable "cloud_image_id" {
  description = "Proxmox file ID of the cloud image to use as the base disk (e.g. local:iso/noble-server-cloudimg-amd64.img)"
  type        = string
}

variable "ip_address" {
  description = "Static IP with CIDR (e.g. '192.168.1.100/24')"
  type        = string
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS server IPs"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "vm_username" {
  description = "Username to create on the VM via cloud-init"
  type        = string
  default     = "spiffyjin"
}

variable "vm_password" {
  description = "Password for the VM user created via cloud-init"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key to inject into the VM"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "List of tags to apply to the VM"
  type        = list(string)
  default     = []
}

variable "network_bridge" {
  description = "Proxmox network bridge to attach the VM to"
  type        = string
  default     = "vmbr0"
}

variable "mac_address" {
  description = "Optional MAC address for the VM NIC. If null, Proxmox assigns one automatically."
  type        = string
  default     = null
}

variable "bios" {
  description = "BIOS type: 'seabios' (default) or 'ovmf' (UEFI, required for HAOS)"
  type        = string
  default     = "seabios"
}
