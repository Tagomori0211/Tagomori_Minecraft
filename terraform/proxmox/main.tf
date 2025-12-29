# proxmox_vm.tf
resource "proxmox_vm_qemu" "minecraft_dashboard" {
  name        = "minecraft-dashboard"
  target_node = "mc-server"  # PROXMOXノード名
  
  # 5700G想定スペック
  cores   = 4
  sockets = 1
  memory  = 4096
  
  # ディスク
  disk {
    size    = "32G"
    type    = "scsi"
    storage = "local-lvm"
  }
  
  # ネットワーク (10GbE想定)
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
  
  # Cloud-init設定
  os_type   = "cloud-init"
  ipconfig0 = "ip=192.168.0.100/24,gw=192.168.0.1"
}