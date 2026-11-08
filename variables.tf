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
  description = "Proxmox node name to build on"
  type        = string
  default     = "pve1"
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

variable "template_vm_id" {
  description = "VM ID of the cloud-init golden template"
  type        = number
  default     = 9000
}

variable "subnet_cidr" {
  description = "CIDR suffix for VM addresses"
  type        = string
  default     = "23"
}

variable "gateway" {
  description = "Default gateway for the VMs"
  type        = string
  default     = "172.16.212.0"
}

variable "ip_base" {
  description = "First three octets for service VM IPs"
  type        = string
  default     = "172.16.212"
}

variable "ip_offset" {
  description = "Host octet of the first service VM (dns-01 gets this)"
  type        = number
  default     = 11
}

variable "ssh_public_key" {
  description = "Public key injected into VMs via cloud-init"
  type        = string
}
