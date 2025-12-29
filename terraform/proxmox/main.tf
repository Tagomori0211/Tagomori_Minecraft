resource "proxmox_vm_qemu" "monitoring" {
  name        = "minecraft-monitoring"
  target_node = "pve"
  clone       = "ubuntu-2404-cloud-init"
  vmid        = 100
  
  cores   = 4
  sockets = 1
  memory  = 4096
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = 32
          storage = "local"
          format  = "raw"
        }
      }
    }
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ipconfig0  = "ip=192.168.0.100/24,gw=192.168.0.1"
  nameserver = "192.168.0.1"
  ciuser     = "tagomori"
  sshkeys    = var.ssh_public_key
  onboot     = true
}

resource "proxmox_vm_qemu" "minecraft_k3s" {
  name        = "minecraft-k3s"
  target_node = "pve"
  clone       = "ubuntu-2404-cloud-init"
  vmid        = 101
  
  cores   = 6
  sockets = 1
  memory  = 8192
  
  disks {
    scsi {
      scsi0 {
        disk {
          size    = 200
          storage = "local"
          format  = "raw"
        }
      }
    }
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  ipconfig0  = "ip=192.168.0.101/24,gw=192.168.0.1"
  nameserver = "192.168.0.1"
  ciuser     = "tagomori"
  sshkeys    = var.ssh_public_key
  onboot     = true
}