terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66" # pin it — 0.x moves fast
    }
  }

  # ---------------------------------------------------------------
  # LAB: local state is fine to start.
  # PRODUCTION: uncomment a remote backend so the team shares state
  # and you get locking + versioning.
  # ---------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "tf-state"
  #   key            = "proxmox/terraform.tfstate"
  #   region         = "us-east-1"
  #   use_path_style = true
  #   endpoints      = { s3 = "https://minio.internal:9000" }
  # }
}

provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token
  insecure  = var.pve_insecure # true for self-signed lab certs

  # Needed for uploading cloud-init snippets / files to the node.
  ssh {
    agent    = true
    username = var.pve_ssh_user
  }
}
