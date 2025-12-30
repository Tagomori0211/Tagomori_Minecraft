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
    
    user_account {
      username = "tagomori"
      password = "tagomori123"
      keys     = [var.ssh_public_key]
    }
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
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_base.id
    
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
      password = "tagomori123"
      keys     = [var.ssh_public_key]
    }
  }
  
  on_boot = true
  started = true
}

# Cloud-init基本設定
resource "proxmox_virtual_environment_file" "cloud_init_base" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "mc-server"

  source_raw {
    data = <<-EOF
    #cloud-config
    timezone: Asia/Tokyo
    
    # SSH設定
    ssh_pwauth: true
    disable_root: false
    
    # パッケージ更新のみ
    package_update: true
    package_upgrade: true
    
    # 基本パッケージ
    packages:
      - python3
      - python3-pip
      - curl
      - git
    
    # SSH設定を有効化
    runcmd:
      - sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      - sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
      - systemctl restart sshd
      - echo 'Base setup complete - ready for Ansible'
    
    final_message: "VM ready for Ansible provisioning"
    EOF

    file_name = "cloud-init-base.yml"
  }
}