output "vm_ips" {
  description = "Static IP assignments for infinity-node VMs"
  value = {
    emby      = "192.168.1.100/24"
    downloads = "192.168.1.101/24"
    arr       = "192.168.1.102/24"
    misc      = "192.168.1.103/24"
    openclaw  = "192.168.1.104/24"
  }
}

output "emby_ip" {
  description = "Static IP for emby"
  value       = "192.168.1.100/24"
}

output "downloads_ip" {
  description = "Static IP for downloads"
  value       = "192.168.1.101/24"
}

output "arr_ip" {
  description = "Static IP for arr"
  value       = "192.168.1.102/24"
}

output "misc_ip" {
  description = "Static IP for misc"
  value       = "192.168.1.103/24"
}

output "openclaw_ip" {
  description = "Static IP for openclaw"
  value       = "192.168.1.104/24"
}
