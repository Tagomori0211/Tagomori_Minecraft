terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.68.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.0.30:8006"
  
  username = var.proxmox_user
  password = var.proxmox_password
  
  insecure = true
  
  ssh {
    agent    = false
    username = "root"
    private_key = file("~/.ssh/proxmox_root")
  }
}