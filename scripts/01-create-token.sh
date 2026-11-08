#!/usr/bin/env bash
# Run ONCE on a Proxmox node, as root.
# Creates a least-privilege role + user + API token for Terraform.
# Never let Terraform use root@pam with a password.
set -euo pipefail

ROLE="TerraformProv"
USER="terraform@pve"
TOKEN="provider"

echo "==> Creating role ${ROLE}"
pveum role add "${ROLE}" -privs \
  "Datastore.Allocate Datastore.AllocateSpace Datastore.Audit \
   Pool.Allocate Sys.Audit Sys.Console Sys.Modify \
   VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit \
   VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory \
   VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor \
   VM.PowerMgmt SDN.Use" 2>/dev/null || echo "    role exists, continuing"

echo "==> Creating user ${USER}"
pveum user add "${USER}" 2>/dev/null || echo "    user exists, continuing"

echo "==> Granting ${ROLE} at /"
pveum aclmod / -user "${USER}" -role "${ROLE}"

echo "==> Creating token — COPY THE VALUE, it is shown only once"
pveum user token add "${USER}" "${TOKEN}" --privsep 0

cat <<'HINT'

Export on your workstation:
  export TF_VAR_pve_api_token='terraform@pve!provider=PASTE-UUID-HERE'
  export TF_VAR_pve_endpoint='https://pve1.internal:8006/'
HINT
