###############################################################################
# PROXMOX SIDE
#
# Builds the actual VM, using the IP NetBox handed out.
# Everything here is driven by inventory.tf — nothing is read back from
# NetBox to decide what exists.
###############################################################################

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = local.vms

  name        = each.key
  description = "Managed by Terraform · ${each.value.comments}"
  node_name   = each.value.node
  tags        = ["terraform", each.value.role]

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  agent {
    enabled = true # needs qemu-guest-agent inside the image
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  # Growing is an in-place "~" change. SHRINKING forces destroy-and-recreate.
  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = each.value.disk
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        # comes from NetBox, already in CIDR form: "172.16.212.11/23"
        address = local.vm_ip[each.key]
        gateway = var.gateway
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      username = "ops"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  lifecycle {
    # Set to true for production entries once you trust the pipeline.
    prevent_destroy = false
  }
}

# ntp-01 used to be element [0] of the old count-based
# proxmox_virtual_environment_vm.svc (02-services.tf). This re-addresses it
# in state instead of planning a delete + create. Safe to remove after one
# successful apply.
moved {
  from = proxmox_virtual_environment_vm.svc[0]
  to   = proxmox_virtual_environment_vm.vm["ntp-01"]
}
