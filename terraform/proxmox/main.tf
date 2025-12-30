# 監視スタックVM (192.168.0.100)
resource "proxmox_virtual_environment_vm" "monitoring" {
  name      = "minecraft-monitoring"
  node_name = "mc-server"
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
    datastore_id      = "local-lvm"
    # Base設定 (cloud-init-base.yml) を使用
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_base.id
    
    ip_config {
      ipv4 {
        address = "192.168.0.100/24"
        gateway = "192.168.0.1"
      }
    }
    
    dns {
      servers = ["192.168.0.1"]
    }

    # Cloud-init側でユーザーを作成するため、Terraform側のuser_accountブロックは削除
  }
  
  on_boot = true
  started = true
}

# マイクラK3s VM (192.168.0.101)
resource "proxmox_virtual_environment_vm" "minecraft_k3s" {
  name      = "minecraft-k3s"
  node_name = "mc-server"
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
    datastore_id      = "local-lvm"
    # 【重要】K3s用設定 (cloud-init-k3s.yml) を使用するように変更
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_k3s.id
    
    ip_config {
      ipv4 {
        address = "192.168.0.101/24"
        gateway = "192.168.0.1"
      }
    }
    
    dns {
      servers = ["192.168.0.1"]
    }
    
    # Cloud-init側でユーザーを作成するため、Terraform側のuser_accountブロックは削除
  }
  
  on_boot = true
  started = true
}

# Cloud-init基本設定 (Base)
resource "proxmox_virtual_environment_file" "cloud_init_base" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "mc-server"

  source_raw {
    # templatefile関数で外部YAMLを読み込み、変数を埋め込む
    data = templatefile("${path.module}/cloud-init/base.yml", {
      ssh_public_key = var.ssh_public_key
    })
    file_name = "cloud-init-base.yml"
  }
}

# Cloud-init K3s設定 (New)
resource "proxmox_virtual_environment_file" "cloud_init_k3s" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "mc-server"

  source_raw {
    # templatefile関数で外部YAMLを読み込み、変数を埋め込む
    data = templatefile("${path.module}/cloud-init/k3s.yml", {
      ssh_public_key = var.ssh_public_key
    })
    file_name = "cloud-init-k3s.yml"
  }
}