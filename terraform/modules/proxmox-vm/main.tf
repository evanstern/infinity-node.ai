# terraform/modules/proxmox-vm/main.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  vm_id     = var.vm_id
  name      = var.name
  node_name = var.node_name
  tags      = var.tags
  bios      = var.bios

  cpu {
    cores = var.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    file_id      = var.cloud_image_id
    interface    = "scsi0"
    size         = var.disk_size
    file_format  = var.disk_file_format
  }

  network_device {
    bridge      = var.network_bridge
    model       = "virtio"
    mac_address = var.mac_address
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = var.vm_username
      password = var.vm_password
      keys     = [var.ssh_public_key]
    }
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    # clone is a one-time creation operation — Proxmox does not persist clone
    # source metadata after the VM is built, so imported VMs will always show
    # a diff here. Ignoring prevents spurious replacements of existing VMs.
    #
    # disk: extra disks (passthrough drives, additional volumes) and disk
    # attributes (aio, cache, backup flags) are managed in Proxmox directly
    # and must not be touched after initial VM creation.
    #
    # startup: boot ordering is managed manually in Proxmox, not via Terraform.
    ignore_changes = [disk, startup, efi_disk, agent, description, scsi_hardware, network_device, initialization]
  }
}
