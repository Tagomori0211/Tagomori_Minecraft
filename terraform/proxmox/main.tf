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
    user_data_file_id = proxmox_virtual_environment_file.monitoring_cloud_init.id
    
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
      password = "tagomori123"  # 一時的なパスワード
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
    user_data_file_id = proxmox_virtual_environment_file.k3s_cloud_init.id
    
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
      password = "tagomori123"
    }
  }
  
  on_boot = true
  started = true
}

# Cloud-init設定: 監視VM
resource "proxmox_virtual_environment_file" "monitoring_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "mc-server"

  source_raw {
    data = <<-EOF
    #cloud-config
    timezone: Asia/Tokyo
    
    # パスワード認証を一時的に有効化
    ssh_pwauth: true
    
    # パッケージ更新
    package_update: true
    package_upgrade: true
    
    # 必須パッケージ
    packages:
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
      - lsb-release
      - git
    
    # Docker環境構築
    runcmd:
      # Docker公式GPGキー追加
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      
      # Dockerリポジトリ追加
      - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      
      # Dockerインストール
      - apt-get update
      - DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      
      # tagonoriユーザーをdockerグループに追加
      - usermod -aG docker tagomori
      
      # Dockerサービス有効化
      - systemctl enable docker
      - systemctl start docker
      
      # 作業ディレクトリ作成
      - mkdir -p /home/tagomori/actions-runner
      - mkdir -p /home/tagomori/Tagomori_Minecraft
      - chown -R tagomori:tagomori /home/tagomori/actions-runner
      - chown -R tagomori:tagomori /home/tagomori/Tagomori_Minecraft
      
      # SSH権限修正（念のため）
      - chmod 700 /home/tagomori/.ssh || true
      - chmod 600 /home/tagomori/.ssh/authorized_keys || true
      
      # システム最適化
      - sysctl -w vm.max_map_count=262144
      - echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    
    final_message: "Monitoring VM (192.168.0.100) setup complete! Docker installed."
    EOF

    file_name = "monitoring-cloud-init.yml"
  }
}

# Cloud-init設定: K3s VM
resource "proxmox_virtual_environment_file" "k3s_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "mc-server"

  source_raw {
    data = <<-EOF
    #cloud-config
    timezone: Asia/Tokyo
    
    ssh_pwauth: true
    
    package_update: true
    package_upgrade: true
    
    packages:
      - curl
      - git
    
    runcmd:
      # K3sインストール
      - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
      
      # kubeconfigセットアップ
      - mkdir -p /home/tagomori/.kube
      - cp /etc/rancher/k3s/k3s.yaml /home/tagomori/.kube/config
      - chown -R tagomori:tagomori /home/tagomori/.kube
      - chmod 600 /home/tagomori/.kube/config
      
      # kubectlエイリアス設定
      - echo "alias kubectl='k3s kubectl'" >> /home/tagomori/.bashrc
      - echo "export KUBECONFIG=/home/tagomori/.kube/config" >> /home/tagomori/.bashrc
      
      # GitHub Actions Runner用ディレクトリ
      - mkdir -p /home/tagomori/actions-runner
      - mkdir -p /home/tagomori/Tagomori_Minecraft
      - chown -R tagomori:tagomori /home/tagomori/actions-runner
      - chown -R tagomori:tagomori /home/tagomori/Tagomori_Minecraft
      
      # SSH権限修正
      - chmod 700 /home/tagomori/.ssh || true
      - chmod 600 /home/tagomori/.ssh/authorized_keys || true
    
    final_message: "K3s VM (192.168.0.101) setup complete! K3s installed."
    EOF

    file_name = "k3s-cloud-init.yml"
  }
}