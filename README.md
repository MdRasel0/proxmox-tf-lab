# Terraform on Proxmox — Practical Lab

Hands-on companion to the bdNOG 22 talk
*"Infrastructure as Code for On-Prem Servers."*

Work through the labs in order. Each one maps to a part of the talk, and
Labs 3–5 are the ones worth doing twice — they are what actually bites
people in production.

| Lab | What you practise | Talk slide |
|-----|-------------------|-----------|
| 0 | Prerequisites and API token | 6 |
| 1 | A single VM from code | 8 |
| 2 | Golden template + clone three services | 9, 10 |
| 3 | **Cause drift, then detect it** | 14, 19 |
| 4 | **Import a VM built in the GUI** | 12, 13 |
| 5 | **Break something, roll it back** | 15 |
| 6 | Pull IPs from NetBox (optional) | 11 |
| 7 | Clean up | — |

> **Layout change:** service VMs are no longer a `count` list in
> `02-services.tf`. They are now defined in **[`inventory.tf`](inventory.tf)**
> (one map entry per VM), built by `proxmox.tf`, with IPs allocated and
> recorded by NetBox in `netbox.tf`. Read **[HYBRID.md](HYBRID.md)** for the
> design and the NetBox prerequisites. Lab 2 and Lab 6 below describe the
> old layout; the ideas still apply, the resource is now
> `proxmox_virtual_environment_vm.vm["<name>"]`.

---

## Lab 0 — Prerequisites

On your workstation:

- Terraform >= 1.6
- Network access to the Proxmox API (port 8006)
- An SSH keypair (`~/.ssh/id_ed25519.pub`)

On a Proxmox node, as root:

```bash
# creates a least-privilege role, user and API token
bash scripts/01-create-token.sh
```

Copy the token value — it is printed **once**. Then on your workstation:

```bash
export TF_VAR_pve_endpoint='https://pve1.internal:8006/'
export TF_VAR_pve_api_token='terraform@pve!provider=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

Copy and edit the non-secret values:

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars      # node name, storage, bridge, IP range
terraform init
```

> Secrets go in environment variables, not in `terraform.tfvars`.
> `.gitignore` already excludes `terraform.tfvars` and all state files.

---

## Lab 1 — A single VM from code

This is the smoke test. It proves the token, the endpoint and the
provider all work before you involve templates or cloud-init.

```bash
terraform plan  -target=proxmox_virtual_environment_vm.lab01
terraform apply -target=proxmox_virtual_environment_vm.lab01
```

**Verify:** `lab01-smoketest` appears in the Proxmox UI under your node.

```bash
terraform plan      # should now say: No changes
```

That "No changes" is the single most important output in Terraform.
It means code, state and reality agree.

---

## Lab 2 — Golden template, then clone

On a Proxmox node, as root:

```bash
bash scripts/02-build-template.sh      # builds template VM 9000
```

Then from your workstation:

```bash
terraform apply -target=proxmox_virtual_environment_vm.svc
terraform output services
```

You now have three VMs from one block of code:

```
dns-01      10.0.10.11
radius-01   10.0.10.12
monitor-01  10.0.10.13
```

```bash
ssh ops@10.0.10.11
```

`count` loops the resource; `count.index` gives each VM its own name and IP.
Add a fourth service to `local.services` in `02-services.tf`, run `plan`,
and watch Terraform propose exactly one new VM.

---

## Lab 3 — Cause drift, then detect it

This is the exercise that teaches the most. You are going to play the
colleague who "just quickly fixed something in the GUI."

**Step 1 — drift it by hand.**
In the Proxmox web UI, select `dns-01` → Hardware → Memory → change
2048 to 4096. Apply.

**Step 2 — detect it.**

```bash
terraform plan -detailed-exitcode
# exit 0 = clean
# exit 2 = drift detected
# exit 1 = error
echo $?
```

Read the plan output. You should see:

```
~ memory {
    ~ dedicated = 4096 -> 2048
  }
```

Terraform wants to undo the manual change, because code is its source of truth.

**Step 3 — decide.** Two valid answers, and this is the judgement call
from the talk:

```bash
# (a) the manual change was wrong — let code win
terraform apply

# (b) the manual change was right — adopt it
#     edit 02-services.tf: memory dedicated = 4096
terraform plan     # should say: No changes
```

**Step 4 — now try the dangerous one.** Change the disk `size` in
`02-services.tf` from 20 down to 10 and run `plan` — **do not apply**:

```
-/+ resource "proxmox_virtual_environment_vm" "svc" {
      ~ disk { size = 20 -> 10 # forces replacement }
```

`-/+` means **destroy and recreate**. The VM and its data would be
deleted and rebuilt. Growing a disk is a safe `~`; shrinking it is not.
Revert the number back to 20 before continuing.

> Put this in your muscle memory: read the symbol before every apply.
> `~` is a change. `-/+` is a rebuild.

Run a scheduled drift check in CI later:

```bash
terraform plan -detailed-exitcode   # alert when exit code is 2
```

---

## Lab 4 — Import a VM built in the GUI

This is how you migrate an existing cluster without rebuilding anything.

**Step 1 — create a VM by hand** in the Proxmox UI (any small VM; note
its VMID, say `142`). Pretend it has been running for two years.

**Step 2 — write a matching resource block** in a new file `04-import.tf`:

```hcl
resource "proxmox_virtual_environment_vm" "legacy" {
  name      = "legacy-01"
  node_name = "pve1"
  # leave the rest minimal for now
}
```

**Step 3 — import it into state:**

```bash
terraform import proxmox_virtual_environment_vm.legacy pve1/142
```

**Step 4 — make the code match reality:**

```bash
terraform plan
```

The plan will list everything that differs. Edit the `.tf` until the plan
says **No changes**. You are editing the *code*, never the VM.

```bash
terraform state show proxmox_virtual_environment_vm.legacy   # see what Terraform recorded
```

**The rule:** import one VM at a time, confirm a clean plan, commit, then
move to the next. Never bulk-import a cluster on a Friday.

---

## Lab 5 — Break something, roll it back

```bash
git init && git add -A && git commit -m "lab: working baseline"
```

**Step 1 — make a bad change.** In `02-services.tf`, drop
`memory.dedicated` to 512.

```bash
git add -A && git commit -m "reduce radius memory"
terraform apply
```

**Step 2 — see what changed:**

```bash
git diff HEAD~1
```

```diff
   memory {
-    dedicated = 2048
+    dedicated = 512
   }
```

**Step 3 — roll it back:**

```bash
git revert HEAD        # creates a new commit undoing it
terraform plan         # ~ memory.dedicated: 512 -> 2048
terraform apply
```

That is the whole rollback story: **revert the commit, re-apply.** Code and
reality stay in sync, and the history records both the mistake and the fix.

> What revert cannot undo: a `-/+` change already applied. The VM was
> destroyed; reverting rebuilds it empty. Config comes back, data does not.
> That is what Proxmox Backup Server is for.

---

## Lab 6 (optional) — IPs from NetBox

Stop hardcoding addresses; let your IPAM hand them out.

```bash
mv 03-netbox.tf.disabled 03-netbox.tf
# add the netbox provider block to providers.tf (instructions in the file)
export TF_VAR_netbox_url='https://netbox.internal'
export TF_VAR_netbox_token='...'
terraform init
terraform plan
```

`netbox_available_ip_address` is a *resource*, not a data source — it
claims the next free IP and records the reservation. `terraform destroy`
releases it again.

---

## Lab 7 — Clean up

```bash
terraform destroy
```

Check the plan before confirming. `destroy` removes everything in state —
including anything you imported in Lab 4.

---

## Quick reference

```bash
terraform init                        # set up provider + backend
terraform fmt -recursive              # format
terraform validate                    # syntax check
terraform plan                        # ALWAYS read before apply
terraform apply                       # make changes
terraform plan -detailed-exitcode     # drift check (2 = drift)
terraform import <addr> <node>/<vmid> # adopt an existing VM
terraform state list                  # what Terraform manages
terraform state show <addr>           # what it recorded
terraform force-unlock <lock-id>      # clear a stale lock (confirm no live apply!)
terraform destroy                     # tear down
```

Or use the Makefile: `make help`

## Reading the plan symbols

| Symbol | Meaning | Risk |
|--------|---------|------|
| `+` | create | safe — nothing existing is touched |
| `~` | update in place | usually safe; some changes need a reboot |
| `-/+` | **destroy and recreate** | **data loss** — read carefully |
| `-` | destroy | gone |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `401 authentication failure` | Bad/expired token | Re-check `user@realm!id=uuid`, regenerate |
| `403 permission denied` on clone | Role missing a privilege | Add the missing `VM.*` priv to the role |
| TLS / certificate error | Self-signed cert | `pve_insecure = true` (lab) or install a real cert |
| cloud-init settings ignored | Snippet upload needs SSH | Check the `ssh {}` block in `providers.tf` |
| VM IP never reported | guest agent missing | Install qemu-guest-agent, or `agent { enabled = false }` |
| Clone fails intermittently | Storage race on parallel clones | `terraform apply -parallelism=2` |
| State lock stuck after crash | Abandoned lock | `terraform force-unlock <id>` once you're sure nothing is running |
