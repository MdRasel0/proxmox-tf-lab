output "smoketest_vm_id" {
  description = "VM ID of the Lab 1 smoke-test VM"
  value       = try(proxmox_virtual_environment_vm.lab01.vm_id, null)
}

output "services" {
  description = "Service VMs created by Lab 2"
  value = {
    for i, name in local.services : name => {
      vm_id = proxmox_virtual_environment_vm.svc[i].vm_id
      ip    = "${var.ip_base}.${var.ip_offset + i}"
      ssh   = "ssh ops@${var.ip_base}.${var.ip_offset + i}"
    }
  }
}
