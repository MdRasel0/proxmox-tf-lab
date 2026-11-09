terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66" # pin it — 0.x moves fast
    }
  }

  backend "pg" {
    schema_name = "terraform_remote_state"
  }
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
