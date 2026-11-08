#!/usr/bin/env bash
# Run ONCE on a Proxmox node, as root.
# Builds the cloud-init golden template that Lab 2 clones from.
set -euo pipefail

VMID="${VMID:-9000}"
NAME="${NAME:-ubuntu-2404-tmpl}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG="/tmp/$(basename "${IMG_URL}")"

echo "==> Downloading cloud image"
[ -f "${IMG}" ] || wget -O "${IMG}" "${IMG_URL}"

# qemu-guest-agent lets Terraform read the VM's IP back.
if command -v virt-customize >/dev/null 2>&1; then
  echo "==> Installing qemu-guest-agent into the image"
  virt-customize -a "${IMG}" --install qemu-guest-agent
else
  echo "!!  libguestfs-tools missing. Either:"
  echo "!!    apt install libguestfs-tools   (then re-run)"
  echo "!!  or set agent { enabled = false } in 02-services.tf"
fi

echo "==> Creating VM ${VMID}"
qm create "${VMID}" --name "${NAME}" --memory 2048 --cores 2 \
  --net0 "virtio,bridge=${BRIDGE}" --scsihw virtio-scsi-pci

echo "==> Importing disk"
qm importdisk "${VMID}" "${IMG}" "${STORAGE}"
qm set "${VMID}" --scsi0 "${STORAGE}:vm-${VMID}-disk-0"

echo "==> Cloud-init drive, boot order, serial console"
qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"
qm set "${VMID}" --boot c --bootdisk scsi0
qm set "${VMID}" --serial0 socket --vga serial0
qm set "${VMID}" --agent enabled=1

echo "==> Converting to template"
qm template "${VMID}"
echo "==> Done. Set template_vm_id = ${VMID} in terraform.tfvars"
