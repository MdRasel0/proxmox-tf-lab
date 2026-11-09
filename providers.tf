terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.118" # pin it — 0.x moves fast
    }
    netbox = {
      source = "e-breuninger/netbox"
      # Stay on 5.x: 6.x is a rewrite (netbox_interface renamed, tags by
      # slug, filter blocks changed). See HYBRID.md "Provider versions".
      version = "~> 5.4"
    }
  }

  # conn_str is deliberately NOT here (it holds a password). CI passes it
  # with -backend-config; locally, set $env:PG_CONN_STR.
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

provider "netbox" {
  server_url           = var.netbox_url
  api_token            = var.netbox_token # needs WRITE access
  allow_insecure_https = var.netbox_insecure
}
