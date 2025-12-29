# 監視スタックVM (192.168.0.100)
resource "proxmox_virtual_environment_vm" "monitoring" {
  name      = "minecraft-monitoring"
  node_name = "mc-server"  # ← 変更
  vm_id     = 100
  
  clone {
    vm_id = 9000
  }
  
  cpu {
    cores = 4
    type  = "host"
  }
  
  memory {
    dedicated = 4096
  }
  
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
  }
  
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
  
  initialization {
    ip_config {
      ipv4 {
        address = "192.168.0.100/24"
        gateway = "192.168.0.1"
      }
    }
    
    dns {
      servers = ["192.168.0.1"]
    }
    
    user_account {
      username = "tagomori"
      keys     = [var.ssh_public_key]
    }
  }
  
  on_boot = true
  started = true
}

# マイクラK3s VM (192.168.0.101)
resource "proxmox_virtual_environment_vm" "minecraft_k3s" {
  name      = "minecraft-k3s"
  node_name = "mc-server"  # ← 変更
  vm_id     = 101
  
  clone {
    vm_id = 9000
  }
  
  cpu {
    cores = 6
    type  = "host"
  }
  
  memory {
    dedicated = 8192
  }
  
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 200
  }
  
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
  
  initialization {
    ip_config {
      ipv4 {
        address = "192.168.0.101/24"
        gateway = "192.168.0.1"
      }
    }
    
    dns {
      servers = ["192.168.0.1"]
    }
    
    user_account {
      username = "tagomori"
      keys     = [var.ssh_public_key]
    }
  }
  
  on_boot = true
  started = true
}