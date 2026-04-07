terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }

  backend "local" {}
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

locals {
  cloud_image_id = "local:iso/noble-server-cloudimg-amd64.img"
}

module "emby" {
  source = "../modules/proxmox-vm"

  vm_id          = 100
  name           = "emby"
  node_name      = "infinity-node"
  cpu_cores      = 3
  memory_mb      = 7521
  disk_size      = 79
  datastore_id   = "local-lvm"
  cloud_image_id = local.cloud_image_id
  ip_address     = "192.168.1.100/24"
  gateway        = var.gateway
  dns_servers    = ["192.168.1.79"]
  vm_username    = var.vm_username
  vm_password    = var.vm_password
  ssh_public_key = var.ssh_public_key
  tags           = ["docker", "emby", "gpu"]
}

module "downloads" {
  source = "../modules/proxmox-vm"

  vm_id          = 101
  name           = "downloads"
  node_name      = "infinity-node"
  cpu_cores      = 8
  memory_mb      = 7519
  disk_size      = 48
  datastore_id   = "local-lvm"
  cloud_image_id = local.cloud_image_id
  ip_address     = "192.168.1.101/24"
  gateway        = var.gateway
  dns_servers    = ["192.168.1.79"]
  vm_username    = var.vm_username
  vm_password    = var.vm_password
  ssh_public_key = var.ssh_public_key
  tags           = ["docker", "downloads", "vpn"]
}

module "arr" {
  source = "../modules/proxmox-vm"

  vm_id          = 102
  name           = "arr"
  node_name      = "infinity-node"
  cpu_cores      = 8
  memory_mb      = 7519
  disk_size      = 97
  datastore_id   = "local-lvm"
  cloud_image_id = local.cloud_image_id
  ip_address     = "192.168.1.102/24"
  gateway        = var.gateway
  dns_servers    = ["192.168.1.79"]
  vm_username    = var.vm_username
  vm_password    = var.vm_password
  ssh_public_key = var.ssh_public_key
  tags           = ["docker", "arr", "media"]
}

module "misc" {
  source = "../modules/proxmox-vm"

  vm_id          = 103
  name           = "misc"
  node_name      = "infinity-node"
  cpu_cores      = 8
  memory_mb      = 15711
  disk_size      = 98
  datastore_id   = "local-lvm"
  cloud_image_id = local.cloud_image_id
  ip_address     = "192.168.1.103/24"
  gateway        = var.gateway
  dns_servers    = ["192.168.1.79"]
  vm_username    = var.vm_username
  vm_password    = var.vm_password
  ssh_public_key = var.ssh_public_key
  tags           = ["docker", "misc"]
}

module "openclaw" {
  source = "../modules/proxmox-vm"

  vm_id          = 104
  name           = "openclaw"
  node_name      = "infinity-node"
  cpu_cores      = 8
  memory_mb      = 7519
  disk_size      = 97
  datastore_id   = "local-lvm"
  cloud_image_id = local.cloud_image_id
  ip_address     = "192.168.1.104/24"
  gateway        = var.gateway
  dns_servers    = ["192.168.1.79"]
  vm_username    = var.vm_username
  vm_password    = var.vm_password
  ssh_public_key = var.ssh_public_key
  tags           = ["docker", "openclaw", "ai"]
}
