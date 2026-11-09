###############################################################################
# THE INVENTORY — this file is the source of truth for WHAT EXISTS.
#
# Adding a server = adding an entry here, in a pull request that someone
# reviews. NetBox never decides what gets built; it only hands out the IP
# and keeps the record afterwards.
#
# Leave `ip` null to let NetBox allocate the next free address from
# var.netbox_prefix. Set it (CIDR form) only when a service needs a fixed
# address, e.g. ip = "172.16.212.50/23".
#
# Careful:
#   - lowering `disk` forces destroy-and-recreate (data loss)
#   - deleting an entry destroys the VM AND releases its IP in NetBox
###############################################################################

locals {
  vms = {
    "ntp-01" = {
      role     = "ntp"
      cores    = 2
      memory   = 2048
      disk     = 50
      node     = "pve1"
      ip       = null # NetBox allocates
      comments = "Pipeline test"
    }
  }

}
