locals {
  vms = {
    "dns-01" = {
      role     = "dns"
      cores    = 2
      memory   = 2048
      disk     = 40
      node     = "pve1"
      ip       = null # NetBox allocates
      comments = "Recursive resolver"
    }
  }
}