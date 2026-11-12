locals {
  vms = {
    "dns-01" = {
      role     = "dns"
      cores    = 4
      memory   = 4096
      disk     = 40
      node     = "pve1"
      ip       = null # NetBox allocates
      comments = "Recursive resolver"
    }
  }
}