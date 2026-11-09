# Hybrid mode — Git decides, NetBox allocates, Proxmox builds

Each system does the one job it is actually good at:

| System | Owns | Does not own |
|--------|------|--------------|
| **Git** | what servers exist | IP addresses |
| **NetBox** | IP addresses, the record of reality | what gets built |
| **Proxmox** | the running VM | nothing — it's the output |

```
  inventory.tf                NetBox                     Proxmox
  (reviewed in a PR)     (hands out an IP)          (VM is built)
        │                       │                        │
        └───── terraform ───────┴────────────────────────┘
                   │
                   └──► writes the VM record back into NetBox
```

The important property: **you can read `inventory.tf` and know exactly what
exists.** Nobody can add a server by clicking in a web UI.

---

## Why this over the other two

**Pure Git (no NetBox)** — you hardcode IPs. Then someone forgets to check
the spreadsheet and ships a conflict.

**Pure NetBox-driven** — a tag removed in a web UI becomes
`terraform destroy`. No merge request, no review, no plan anyone read.

**Hybrid** — adding a server is a reviewed commit, the IP comes from the
IPAM that already knows what's free, and NetBox never goes stale because
Terraform writes the record itself.

---

## Files

| File | Purpose |
|------|---------|
| `inventory.tf` | **the one you edit** — what servers exist |
| `netbox.tf` | allocates IPs, writes records back |
| `proxmox.tf` | builds the VMs |
| `variables.tf` | endpoints, defaults |
| `providers.tf` | provider pins |

---

## Part 1 — NetBox prerequisites (one-time)

1. **Cluster type** `Proxmox` → **Cluster** `pve-cluster`
   (Virtualization → Cluster Types / Clusters)
2. **Prefix** `172.16.212.0/23` (IPAM → Prefixes) — IPs are allocated from this
3. **Tag** `terraform` (Customization → Tags)
4. **Custom field** `pve_node`, Type = Text, object type = Virtual Machine
5. **API token with WRITE access** — unlike the read-only NetBox-driven
   setup, Terraform creates records here

---

## Part 2 — Run it

```powershell
$env:TF_VAR_pve_endpoint   = 'https://172.16.213.11:8006/'
$env:TF_VAR_pve_api_token  = 'terraform@pve!provider=...'
$env:TF_VAR_netbox_url     = 'https://netbox.internal'
$env:TF_VAR_netbox_token   = '...'
$env:TF_VAR_ssh_public_key = Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub -Raw

cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
terraform output inventory
```

---

## Part 3 — Adding a server

Edit `inventory.tf`:

```hcl
"ntp-01" = {
  role     = "ntp"
  cores    = 1
  memory   = 1024
  disk     = 10
  node     = "pve1"
  ip       = null          # NetBox picks the next free address
  comments = "Stratum 2 time source"
}
```

Then:

```bash
git checkout -b add-ntp-01
git commit -am "add ntp-01"
# open a pull request — the pipeline runs terraform plan
# a colleague reads the plan and approves
# merge → apply
```

One commit produces: a NetBox VM record, an interface, an allocated IP,
the primary-IP assignment, and the running Proxmox VM.

---

## Fixed vs allocated IPs

```hcl
ip = null              # NetBox allocates the next free address
ip = "172.16.212.50/23"   # you pin it; Terraform registers it in NetBox
```

Use `null` by default. Pin only where the address is referenced somewhere
you can't easily change — a bookmarked dashboard, a firewall rule, an NS
record.

---

## What happens when you change things

| Change in `inventory.tf` | Result |
|--------------------------|--------|
| Add an entry | NetBox record + IP + Proxmox VM created |
| Raise `memory` or `cores` | `~` in place (reboot may be needed) |
| Raise `disk` | `~` disk grows |
| **Lower `disk`** | **`-/+` destroy and recreate — data loss** |
| Change `node` | migration or replacement — read the plan |
| Change `ip` null → fixed | the allocated IP is released, the fixed one registered, VM reconfigured |
| **Delete an entry** | VM destroyed, NetBox record deleted, **IP released back to the pool** |

That last row deserves care: deleting three lines from `inventory.tf`
releases the IP for reuse. If something still points at that address, it
will be handed to a different server later.

---

## Guardrails

**Plan in CI, apply from CI.** NetBox now has write access from Terraform;
nobody should be running `apply` from a laptop.

**Grep the plan for destroys** until you trust it:

```bash
terraform plan -out=tfplan
terraform show tfplan | grep -E "will be destroyed|forces replacement"
```

**Protect the production entries** while you're still learning:

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}
```

**Allocate serially at first.** `netbox_available_ip_address` has
historically produced duplicate addresses when several are created at once:

```bash
terraform apply -parallelism=1
```

---

## Provider versions — read before you upgrade

This config targets **netbox provider 5.x**. Version **6.0.0** (November
2026) is a complete rewrite on the Plugin Framework. If you move to it,
these changes affect this config:

| 5.x | 6.x |
|-----|-----|
| `netbox_interface` | `netbox_virtual_machine_interface` |
| `netbox_primary_ip` (implicitly VM) | `netbox_primary_ip` (merged device/VM) |
| tags referenced by **name** | tags referenced by **slug** |
| `filter { name, value }` blocks | `filters` — a set of objects |

Some resources migrate state automatically on first refresh; others must be
removed from state and re-imported. Check the project's migration guide
before upgrading, and do it in a branch with a plan you read carefully.

The Proxmox provider is pinned at `~> 0.66` for the same reason — 0.x moves
fast. Confirm the current release and bump deliberately.

---

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| `Error: cluster not found` | `netbox_cluster_name` doesn't match the NetBox cluster exactly |
| `prefix not found` | The prefix in `netbox_prefix` isn't created in NetBox IPAM |
| Duplicate IPs allocated | Parallel allocation — retry with `-parallelism=1` |
| `403` from NetBox | Token is read-only; hybrid mode needs write access |
| Custom field `pve_node` rejected | Field not created, or not assigned to the Virtual Machine object type |
| VM has no network after boot | Gateway doesn't belong to the allocated prefix |
| `Cycle` error on plan | Usually a hand-edit linking Proxmox back into the NetBox resources — keep the direction one-way |
