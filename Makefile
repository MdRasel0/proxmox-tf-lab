# Convenience targets for the lab. Run `make help` for the list.
.PHONY: help init fmt validate plan apply drift smoke vms destroy

help:
	@grep -E '^[a-z-]+:.*?##' $(MAKEFILE_LIST) | sed 's/:.*##/\t/'

init:      ## download the provider, set up the backend
	terraform init

fmt:       ## format the .tf files
	terraform fmt -recursive

validate:  ## check syntax
	terraform validate

plan:      ## preview changes — ALWAYS read this before apply
	terraform plan

apply:     ## make the changes
	terraform apply

drift:     ## exit 0 = clean, exit 2 = something drifted
	terraform plan -detailed-exitcode

smoke:     ## Lab 1 only
	terraform apply -target=proxmox_virtual_environment_vm.lab01

vms:       ## inventory VMs only (inventory.tf)
	terraform apply -target=proxmox_virtual_environment_vm.vm

destroy:   ## tear the lab down
	terraform destroy
