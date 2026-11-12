#output "smoketest_vm_id" {
#  description = "VM ID of the Lab 1 smoke-test VM"
#  value       = try(proxmox_virtual_environment_vm.lab01.vm_id, null)
#}

output "inventory" {
  description = "What was built, and the IP NetBox handed out"
  value = {
    for k, v in local.vms : k => {
      node    = v.node
      cores   = v.cores
      memory  = "${v.memory} MB"
      ip      = local.vm_ip[k]
      source  = v.ip == null ? "netbox-allocated" : "fixed in git"
      proxmox = proxmox_virtual_environment_vm.vm[k].vm_id
      ssh     = "ssh ops@${split("/", local.vm_ip[k])[0]}"
    }
  }
}
