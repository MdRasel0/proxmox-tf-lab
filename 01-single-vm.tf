###############################################################################
# LAB 1 — a single VM from code  (this is Demo 1 in the talk)
#
# No template needed. This creates an empty VM so you can prove the
# provider, the token and the network path all work before anything else.
#
#   terraform plan  -target=proxmox_virtual_environment_vm.lab01
#   terraform apply -target=proxmox_virtual_environment_vm.lab01
###############################################################################

resource "proxmox_virtual_environment_vm" "lab01" {
  name        = "lab01-smoketest"
  description = "Created by Terraform — safe to destroy"
  node_name   = var.pve_node
  tags        = ["terraform", "lab"]

  # Do not power it on; we only care that it gets created.
  started = false

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = 20
  }

  network_device {
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26" # Linux 2.6+
  }
}
