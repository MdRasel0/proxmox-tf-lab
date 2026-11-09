###############################################################################
# NETBOX SIDE
#
# Two jobs only:
#   1. hand out IP addresses  (NetBox is the IPAM source of truth)
#   2. record what was built  (so NetBox is never stale)
#
# It does NOT decide what exists — inventory.tf does.
#
# Dependency order Terraform works out by itself:
#   VM record -> interface -> IP -> primary IP -> Proxmox VM
###############################################################################

data "netbox_cluster" "pve" {
  name = var.netbox_cluster_name
}

data "netbox_prefix" "mgmt" {
  cidr = var.netbox_prefix
}

# --- 1. The VM record in NetBox -------------------------------------------
resource "netbox_virtual_machine" "vm" {
  for_each = local.vms

  name         = each.key
  cluster_id   = data.netbox_cluster.pve.id
  status       = "active"
  vcpus        = each.value.cores
  memory_mb    = each.value.memory
  disk_size_mb = each.value.disk * 1024 # inventory is in GB, NetBox 5.x wants MB
  comments     = each.value.comments
  tags         = ["terraform"]

  custom_fields = {
    pve_node = each.value.node
  }
}

# --- 2. One interface per VM ----------------------------------------------
# NOTE: in provider v6 this resource is named netbox_virtual_machine_interface
resource "netbox_interface" "eth0" {
  for_each = local.vms

  name               = "eth0"
  virtual_machine_id = netbox_virtual_machine.vm[each.key].id
}

# --- 3a. Dynamic IPs: claim the next free address from the prefix ---------
resource "netbox_available_ip_address" "dynamic" {
  for_each = { for k, v in local.vms : k => v if v.ip == null }

  prefix_id                    = data.netbox_prefix.mgmt.id
  virtual_machine_interface_id = netbox_interface.eth0[each.key].id
  status                       = "active"
  dns_name                     = "${each.key}.${var.dns_domain}"
  description                  = "Allocated by Terraform"
}

# --- 3b. Fixed IPs: register the address we chose in inventory.tf ---------
resource "netbox_ip_address" "fixed" {
  for_each = { for k, v in local.vms : k => v if v.ip != null }

  ip_address                   = each.value.ip
  status                       = "active"
  virtual_machine_interface_id = netbox_interface.eth0[each.key].id
  dns_name                     = "${each.key}.${var.dns_domain}"
  description                  = "Fixed address, declared in Terraform"
}

# --- Resolve whichever branch applies, per VM -----------------------------
locals {
  vm_ip = {
    for k, v in local.vms : k => (
      v.ip == null
      ? netbox_available_ip_address.dynamic[k].ip_address
      : netbox_ip_address.fixed[k].ip_address
    )
  }

  vm_ip_id = {
    for k, v in local.vms : k => (
      v.ip == null
      ? netbox_available_ip_address.dynamic[k].id
      : netbox_ip_address.fixed[k].id
    )
  }
}

# --- 4. Mark it primary so NetBox shows it on the VM page -----------------
# NOTE: in provider v6 this is netbox_primary_ip (merged device/VM versions)
resource "netbox_primary_ip" "vm" {
  for_each = local.vms

  virtual_machine_id = netbox_virtual_machine.vm[each.key].id
  ip_address_id      = local.vm_ip_id[each.key]
}
