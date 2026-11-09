########################  Proxmox  ########################
variable "pve_endpoint" {
  description = "Proxmox API endpoint, e.g. https://pve1.internal:8006/"
  type        = string
}

variable "pve_api_token" {
  description = "Proxmox API token: user@realm!tokenid=uuid (pass via TF_VAR_pve_api_token)"
  type        = string
  sensitive   = true
}

variable "pve_insecure" {
  description = "Skip TLS verification (self-signed lab certs)"
  type        = bool
  default     = true
}

variable "pve_ssh_user" {
  description = "SSH user on the Proxmox node (for file uploads)"
  type        = string
  default     = "root"
}

variable "pve_node" {
  description = "Node for the Lab 1 smoke-test VM (inventory VMs set their own node)"
  type        = string
  default     = "pve1"
}

variable "template_vm_id" {
  description = "VM ID of the cloud-init golden template"
  type        = number
  default     = 9000
}

variable "datastore" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag, or null for untagged"
  type        = number
  default     = null
}

########################  NetBox  ########################
variable "netbox_url" {
  description = "NetBox base URL, e.g. https://netbox.internal"
  type        = string
}

variable "netbox_token" {
  description = "NetBox API token — needs WRITE access, Terraform creates records"
  type        = string
  sensitive   = true
}

variable "netbox_insecure" {
  description = "Skip TLS verification for NetBox"
  type        = bool
  default     = true
}

variable "netbox_cluster_name" {
  description = "Proxmox cluster object name in NetBox"
  type        = string
  default     = "pve-cluster"
}

variable "netbox_prefix" {
  description = "Prefix dynamic IPs are allocated from (must exist in NetBox IPAM)"
  type        = string
  default     = "172.16.212.0/23"
}

########################  Network  ########################
variable "gateway" {
  description = "Default gateway for the VMs (must be inside netbox_prefix)"
  type        = string
  default     = "172.16.212.1"
}

variable "dns_domain" {
  description = "Search domain; also used for the NetBox dns_name"
  type        = string
  default     = "internal"
}

variable "dns_servers" {
  description = "Resolvers pushed via cloud-init"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_public_key" {
  description = "Public key injected into VMs via cloud-init"
  type        = string
}
