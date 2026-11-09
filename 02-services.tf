###############################################################################
# LAB 2 — clone the golden template into three familiar service VMs
#         (this is Demo 2 in the talk)
#
# Requires the cloud-init template built by scripts/02-build-template.sh
#
#   dns-01      10.0.10.11
#   radius-01   10.0.10.12
#   monitor-01  10.0.10.13
#
# count loops the block; count.index gives each VM its own name and IP.
###############################################################################

locals {
  services = ["ntp", "dns"]
}

resource "proxmox_virtual_environment_vm" "svc" {
  count = length(local.services)

  name        = "${local.services[count.index]}-01"
  description = "Managed by Terraform — ${local.services[count.index]}"
  node_name   = var.pve_node
  tags        = ["terraform", local.services[count.index]]

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = true # needs qemu-guest-agent inside the image
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
  }

  # Grow the cloned disk. NOTE: growing is an in-place "~" change.
  # SHRINKING this number later forces destroy-and-recreate.
  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "${var.ip_base}.${var.ip_offset + count.index}/${var.subnet_cidr}"
        gateway = var.gateway
      }
    }

    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }

    user_account {
      username = "ops"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  lifecycle {
    # Safety net: refuse to silently destroy a service VM.
    # Comment this out when you deliberately want to replace one.
    prevent_destroy = false
  }
}
