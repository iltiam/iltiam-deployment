# Runbook 1: Oracle Always Free account (Riyadh), $10 budget alert, one Ampere A1 VM with Docker

> **Plan ID:** DEP#7 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #1 in Thabit's list
> **Blocked by:** none
> **Blocks:** AI-12, DEP#2, DEP#9, DEP-02
> **SRS:** SRS §17; NFR-AVA-01; FR-P-7.1 (PDPL)

## Context

Free-first (ADR-0004): Oracle **Always Free** in the Riyadh home region: one Ampere A1 (ARM, aarch64) VM with **2 OCPUs and 12 GB** (Oracle's current Always Free A1 allowance), 200 GB block storage in total, 20 GB object storage, software-protected Vault keys. Staging and production share this one VM as separate Compose projects. ben-fatah owns the account (card for identity verification). This issue creates the account, the money
guard-rail and the single server both environments run on. Re-scoped from "Staging deployment workflow and hosting
decision" (the CD workflow is DEP-03). Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] Commit `docs/adr/0004-hosting.md` (reviewed draft) with status Accepted.
- [ ] Sign up at oracle.com/cloud/free with ben-fatah's name, phone and card. **Home region: Saudi Arabia Central (Riyadh)**: Always Free compute exists only in the home region and the home region cannot be changed.
- [ ] Enable MFA for your user; create a second administrator (a teammate, MFA on) as break-glass.
- [ ] **Budget alert ($10)**: Billing & Cost Management -> Budgets -> Create Budget: root compartment, monthly amount **10 USD**; alert rules on ACTUAL spend at **50 %, 80 %, 100 %** (+ one FORECAST 100 %), emailed to ben-fatah and one teammate. Any charge at all is then visible within the day. Test with a 1 USD budget, then delete it.
- [ ] Identity -> Compartments: create `iltiam` (both environments live in it; production gets its own compartment only if it moves to its own VM).
- [ ] Networking -> Start VCN Wizard -> "Create VCN with Internet Connectivity" in `iltiam`. Security list ingress: **TCP 22 only** (web traffic comes through the Cloudflare Tunnel, DEP#9).
- [ ] Compute -> Create instance `iltiam-1`: image **Canonical Ubuntu 24.04 (aarch64)**, shape **VM.Standard.A1.Flex, 2 OCPUs, 12 GB** (shown as "Always Free-eligible"), boot volume 50 GB; paste your SSH public key.
- [ ] **"Out of host capacity"**: Riyadh has one availability domain, so retry later or run the documented retry loop (OCI CLI `oci compute instance launch ...` every 60 s for up to a few days). If it still fails after 3 days, **upgrade to Pay As You Go**: Oracle keeps Always Free resources free after the upgrade and charges only above the limits; the $10 alert guards against accidental paid resources.
- [ ] Block Storage -> Create a 150 GB block volume (50 + 150 = the 200 GB free total), attach it, mount at `/srv/iltiam` (iSCSI commands from the console, `mkfs.ext4`, `/etc/fstab`).
- [ ] On the VM: `timedatectl set-timezone Asia/Riyadh`; unattended-upgrades; fail2ban; `PasswordAuthentication no`; a 4 GB swap file; user `deploy` in group `docker`; Docker Engine + compose plugin from docs.docker.com ("Install using the apt repository", arm64).
- [ ] **Idle reclamation**: Oracle may reclaim an Always Free instance that is idle for 7 days (CPU p95, network and, for A1, memory all under 20 %). Two running environments keep memory above 20 %; note it in the runbook and alert on instance state (DEP#10).
- [ ] **Fallback** if sign-up fails twice or takes over 48 h: AWS Bahrain (me-south-1), synthetic data only; production stays blocked until an in-Kingdom account works.
- [ ] Write `docs/runbooks/01-oci-account-and-vm.md`.

## Acceptance criteria

- [ ] Account home region is Riyadh; MFA on; the $10 budget has its alert rules and a test alert email arrived.
- [ ] VM `iltiam-1` is A1 2 OCPU / 12 GB, Always Free-eligible, reachable by SSH key only; `uname -m` prints `aarch64`; `docker run hello-world` works; the volume is mounted after reboot.
- [ ] Billing shows $0 after one week.

## Tests required

- Reboot test; password SSH refused; AI-12 runs on this VM next.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
