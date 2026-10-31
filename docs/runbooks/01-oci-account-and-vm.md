# Runbook 1: Oracle Always Free account (Riyadh), $10 budget alert, one Ampere A1 VM with Docker

- **Issue:** iltiam/iltiam-deployment#7 (DEP#7). **Decision record:** [ADR-0004](../adr/0004-hosting.md).
- **Who:** anyone on the team. No cloud experience needed; follow the steps in order.
- **Time:** about 2 hours, plus waiting if Oracle has no free capacity (section 7).
- **Result:** one Oracle Cloud account in Riyadh with a $10 budget alarm, and one VM, `iltiam-1` (Ampere A1, **2 OCPU / 12 GB**, Ubuntu 24.04, aarch64), with Docker, a 4 GB swap file and a 100 GB data volume at `/srv/iltiam`. Staging and production both run on this VM later (Runbook 5).

> **Never paste a secret into this runbook, an issue, a PR or a chat.** That includes private keys, passwords, OCI API keys and `~/.oci/config`. Never write the VM's public IP, OCIDs or the tenancy name into the repo either: use the placeholders below.

| Placeholder | Meaning |
|---|---|
| `<PUBLIC_IP>` | The VM's public IPv4 address (Compute → Instances → `iltiam-1`) |
| `<YOUR_EMAIL>`, `<TEAMMATE_EMAIL>` | Budget alert recipients |
| `<COMPARTMENT_OCID>`, `<SUBNET_OCID>`, `<IMAGE_OCID>`, `<AD_NAME>` | Only for the CLI retry loop in section 7 |

Console menu names move between Oracle console releases. If a menu below is not where this says, type its name into the console's search bar.

## As built (2026-10-27)

| Item | Value |
|---|---|
| Region | Saudi Arabia Central (Riyadh), AD-1 (the only availability domain) |
| Budget | `iltiam-monthly-budget`, 10 USD monthly, root compartment |
| Compartment | `iltiam` |
| Network | VCN `iltiam-vcn`, public subnet `10.0.0.0/24`; ingress TCP 22 only |
| Instance | `iltiam-vm` in the OCI console (**Compute → Instances**); hostname `iltiam-1`, the name the other runbooks use. `VM.Standard.A1.Flex`, 2 OCPU / 12 GB, Canonical Ubuntu 24.04 aarch64 |
| Boot volume | 100 GB, VPU 10 (Balanced), in-transit encryption on |
| Data volume | 100 GB, VPU 10, attached from the volume page (no device path), ext4 at `/srv/iltiam`, mounted by UUID |
| Storage total | 100 + 100 = **200 GB**, the whole Always Free block storage allowance |
| Software | Docker Engine 29.x (arm64), Compose plugin v5.x, 4 GB swap, fail2ban, unattended-upgrades |

## Why 2 OCPU / 12 GB, not 4 / 24

Always Free covers **1,500 OCPU-hours and 9,000 GB-hours of A1 a month**. That is exactly one VM of 2 OCPU / 12 GB running all month (2 × 750 h, 12 × 750 h).

The create-instance form still lets you pick 4 OCPU / 24 GB. During the 30-day trial, the trial credits silently pay for the extra half. **When the trial ends, an A1 instance above the Always Free limit is disabled**, and everything on it stops.

So:

- Always create **2 OCPU / 12 GB**.
- If you already created something bigger, shrink it now (section 6.3). Don't wait for the trial to end.

## 1. Before you start

- A card in the account holder's name (Oracle uses it for identity checks; Always Free use is not charged), a phone for SMS, and an email address.
- A laptop with OpenSSH. Windows 10/11 has it built in: use PowerShell or Git Bash.
- About 2 hours.

## 2. Create the account

1. Go to **oracle.com/cloud/free** → **Start for free**.
2. Fill in the account holder's real name, email and country (Saudi Arabia).
3. **Home Region: Saudi Arabia Central (Riyadh).** Check this twice. Always Free compute exists only in the home region, and **the home region can never be changed**.
4. Verify the phone number and add the card. Oracle may place a small temporary hold on the card.
5. Wait for the "Your account is ready" email (minutes to a few hours), then sign in at **cloud.oracle.com** with the cloud account name from that email.

**If sign-up fails twice or takes more than 48 hours:** stop. The fallback is AWS Bahrain (me-south-1) with **synthetic data only**. Production stays blocked until an in-Kingdom account works (ADR-0004).

## 3. Protect the account: MFA and a break-glass administrator

1. Top-right profile menu → **My profile** → **Security** (sometimes "Access & security") → **2-Step Verification** → enroll an authenticator app. Sign out and back in to check it asks for the code.
2. **☰ → Identity & Security → Domains → Default domain → User management → Create user:** a teammate's name and email.
3. **Groups → Administrators → Assign user to group** → add the teammate.
4. The teammate accepts the email invitation, sets a password and **enables 2-Step Verification on their own account the same day.**

This second administrator is the break-glass account if the owner loses their phone.

## 4. Budget alert ($10)

The aim: **any charge at all** is emailed to two people the same day.

1. **☰ → Billing & Cost Management → Budgets → Create Budget.**
   - Name: `iltiam-monthly-budget`
   - Scope: **Compartment**, the **root** compartment (the tenancy itself, so it covers everything)
   - Schedule: **Monthly**, amount **10** (USD), processing starts on day 1
   - First alert rule: **Actual Spend**, **Absolute amount**, **1**, recipients `<YOUR_EMAIL>, <TEAMMATE_EMAIL>`
   - **Create.**
2. Open the budget → **Budget alert rules → Create alert rule**, once per row below. Every rule goes to both recipients.

| # | Threshold metric | Threshold type | Threshold | Fires when |
|---|---|---|---|---|
| 1 | Actual Spend | Absolute amount | 1 | Real spend reaches $1 (the early warning) |
| 2 | Actual Spend | Percentage of budget | 50 | $5 spent |
| 3 | Actual Spend | Percentage of budget | 80 | $8 spent |
| 4 | Actual Spend | Percentage of budget | 100 | $10 spent |
| 5 | Forecast Spend | Percentage of budget | 100 | Oracle forecasts $10 by month end |

3. **What you should see:** the budget lists **5 alert rules**, each with both email addresses.

**Testing the alert:** Oracle budgets have no "send test email" button, and with $0 spend no rule fires. **Do not create a paid resource just to test it.** Check instead that the 5 rules and both email addresses are correct, and add both addresses to your mail contacts so the alert doesn't land in spam. The first real alert email is the end-to-end test.

## 5. Compartment and network

### 5.1 Compartment

**☰ → Identity & Security → Compartments → Create Compartment**:

- Name `iltiam`, description "ILTIAM staging and production".
- Parent: root.

Everything below goes into `iltiam`. (Production gets its own compartment only if it ever moves to its own VM.)

### 5.2 Network (VCN)

1. **☰ → Networking → Virtual cloud networks.** Pick compartment `iltiam` on the left → **Start VCN Wizard → Create VCN with Internet Connectivity → Start VCN Wizard.**
2. Name `iltiam-vcn`. Keep the default CIDRs; the public subnet is `10.0.0.0/24`. **Next → Create.**
3. Open `iltiam-vcn` → **Security** (or **Security Lists**) → **Default Security List for iltiam-vcn → Ingress rules.** The only TCP rule must be:

   | Source | Protocol | Destination port |
   |---|---|---|
   | `0.0.0.0/0` | TCP | 22 |

   The wizard also adds ICMP rules (type 3, 4). Keep them; they are needed for path-MTU discovery. **Delete any rule for 80, 443 or other ports.** Web traffic will arrive through the Cloudflare Tunnel (Runbook 3, DEP#9), which only makes **outbound** connections.

If you create the network from the instance form instead ("Create new virtual cloud network" / "Create new public subnet"), it works, but read gotcha 2 in section 6.2.

## 6. Create the VM `iltiam-1`

### 6.1 SSH key (on your laptop)

Generate the key on your laptop. **Only the `.pub` file is ever uploaded.** The private key never leaves the laptop and is never committed, emailed or pasted anywhere.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/iltiam_oci -C "iltiam-oci"
```

Give it a passphrase. This creates `~/.ssh/iltiam_oci` (private, keep it secret) and `~/.ssh/iltiam_oci.pub` (public, upload this one). On Windows, `~` is `C:\Users\<you>`.

### 6.2 Create the instance

**☰ → Compute → Instances**, compartment `iltiam` → **Create instance.**

1. **Name:** `iltiam-1`. **Compartment:** `iltiam`.
2. **Placement:** AD-1 (Riyadh has only one).
3. **Image and shape → Change shape → Virtual machine → Ampere → `VM.Standard.A1.Flex`.** Set **OCPUs 2, Memory 12 GB → Select shape.** The shape should show **"Always Free-eligible"**.
4. **Change image → Ubuntu → Canonical Ubuntu 24.04** (not "Minimal"). With an Ampere shape the console offers the **aarch64** build.
5. **Networking:**
   - Select existing VCN `iltiam-vcn`, its **public** subnet.
   - **Assign a public IPv4 address: Yes.**
   - **VNIC name and hostname: `iltiam-1`.** **Gotcha 3:** Ubuntu takes its hostname from the VNIC hostname. If you leave a wizard default (for example `iltiam-vnic`), the VM is called that. The bootstrap script (section 9) renames it to `iltiam-1` either way.
6. **Add SSH keys → Upload public key files (.pub)** → `~/.ssh/iltiam_oci.pub`.
7. **Boot volume:**
   - **Specify a custom boot volume size: 100 GB.**
   - **VPU 10** (Balanced).
   - **Use in-transit encryption: on.**
8. **Review page (gotcha 1): read the shape line again before you click Create.** Editing other fields can quietly reset the shape to the default **1 OCPU / 6 GB**. It must say **2 OCPU, 12 GB memory**. If it doesn't, go back to step 3.
9. **Create.** Wait for the state to turn **Running** (1–3 minutes). Copy the **Public IPv4 address**; that is your `<PUBLIC_IP>`.

**What you should see:** `iltiam-1`, Running, shape `VM.Standard.A1.Flex` (2 OCPU, 12 GB), and a public IPv4 address.

**Gotcha 2: no public IP.** If you chose "Create new public subnet" in the instance form, the "Assign public IPv4 address" toggle stays disabled and the VM gets no public IP. Fix it after creation:

1. Instance → **Networking** (or **Attached VNICs**) → the primary VNIC → **IP administration** (or **IPv4 addresses**).
2. On the primary private IP: **⋮ → Edit → Public IP type: Ephemeral public IP → Update.**

### 6.3 Shrink a 4 / 24 instance to 2 / 12 (Edit shape)

Only needed if the instance was created bigger than 2 OCPU / 12 GB (see "Why 2 OCPU / 12 GB" above).

1. **Compute → Instances → `iltiam-1` → Edit → Edit shape** (on some consoles: **More actions → Edit → Edit shape**).
2. Keep `VM.Standard.A1.Flex`. Set **OCPUs 2, Memory 12 GB → Save changes.**
3. The console warns that the instance **reboots**. Confirm. Wait for **Running**.
4. On the VM: `nproc` prints `2`, and `free -h` shows about **11Gi** total memory.

### 6.4 Move existing resources into `iltiam` (if they were created in root)

Moving an instance **does not move its boot volume or its VNIC** (Oracle documentation), so move each resource on its own:

1. **Compute → Instances → `iltiam-1` → More actions → Move resource →** `iltiam`.
2. **Storage → Block Storage → Boot volumes →** `iltiam-1 (Boot Volume)` **→ Move resource →** `iltiam`.
3. **Networking → Virtual cloud networks → `iltiam-vcn` → Move resource →** `iltiam`. Then open the VCN and move its **subnets** too.

Check: each resource's **Compartment** field reads `iltiam`. The VNIC stays where it was; leave it. Then run `ssh iltiam` (section 8) to confirm the VM still answers.

**Moving the VCN does not move its Default Security List.** Ours stayed in root. To find it (section 5.2 step 3, checklist row 25), switch the **compartment filter on the left to root**. It still protects the subnet from there, so it is fine to leave it in root.

## 7. If you see "Out of host capacity"

This means Oracle has no free A1 machines in Riyadh right now. Riyadh has a single availability domain, so you can't switch to another one. Work through these in order:

1. **Retry by hand** a few times a day, early morning and late night especially.
2. **Retry loop with the OCI CLI** (every 60 s, for up to 3 days). This needs the OCI CLI and an **API signing key** (`oci setup config`). The key and `~/.oci/config` are secrets: never commit them, and delete the API key from your user (**My profile → API keys**) once the VM exists. **This loop has not been tested by us**, because we got capacity first time. Read the first error: if it is anything other than "Out of host capacity", stop it with Ctrl+C and fix the error first.

   ```bash
   until oci compute instance launch \
       --compartment-id <COMPARTMENT_OCID> \
       --availability-domain <AD_NAME> \
       --display-name iltiam-1 \
       --hostname-label iltiam-1 \
       --shape VM.Standard.A1.Flex \
       --shape-config '{"ocpus": 2, "memoryInGBs": 12}' \
       --image-id <IMAGE_OCID> \
       --subnet-id <SUBNET_OCID> \
       --assign-public-ip true \
       --boot-volume-size-in-gbs 100 \
       --is-pv-encryption-in-transit-enabled true \
       --ssh-authorized-keys-file ~/.ssh/iltiam_oci.pub; do
     echo "$(date) no capacity, retrying in 60 s"
     sleep 60
   done
   ```

3. **Still failing after 3 days: upgrade to Pay As You Go.** Go to **Billing & Cost Management → Upgrade and Manage Payment**. Oracle keeps Always Free resources free after the upgrade and charges only for use above the limits, and the budget alerts (section 4) catch any accidental paid resource. Community reports say PAYG accounts get capacity more easily; that is anecdotal, not an Oracle promise.

## 8. First login from your laptop

```bash
ssh -i ~/.ssh/iltiam_oci ubuntu@<PUBLIC_IP>
```

Type `yes` to the host-key question the first time. **What you should see:** an Ubuntu 24.04 welcome banner and a `ubuntu@...:~$` prompt.

**Optional shortcut (gotcha 5).** Add this to `~/.ssh/config` (Windows: `C:\Users\<you>\.ssh\config`):

```
Host iltiam
    HostName <PUBLIC_IP>
    User ubuntu
    IdentityFile ~/.ssh/iltiam_oci
    IdentitiesOnly yes
```

From then on, `ssh iltiam` and `scp file iltiam:~` are enough. This file holds the IP, so keep it on your laptop only.

## 9. Bootstrap the VM

[`scripts/bootstrap-vm.sh`](../../scripts/bootstrap-vm.sh) does everything on the VM in one go. It is **safe to run again**: a second run changes nothing and just prints the summary. It:

- **Updates packages:** `apt update` and `upgrade`, without prompts.
- **Sets the hostname to `iltiam-1`,** and keeps it there:
  - `/etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg` (`preserve_hostname: true`) stops cloud-init from putting the VNIC name back on reboot;
  - a `127.0.1.1 iltiam-1` line in `/etc/hosts` lets `sudo` resolve the new name.
- **Sets the timezone** to `Asia/Riyadh`.
- **Installs Docker Engine and the Compose plugin** from Docker's apt repository (docs.docker.com, arm64). If Docker is already installed from that repository, for example via get.docker.com, it is left as is.
- **Creates the user `deploy`** with no password, so it is reachable only by SSH key. Its key is added by the CD runbook (DEP-03). It adds `deploy` and `ubuntu` to the `docker` group.
- **Enables unattended-upgrades** for daily security updates. It never reboots by itself.
- **Turns on key-only SSH** with `/etc/ssh/sshd_config.d/01-iltiam.conf`, which sets `PasswordAuthentication no`, `KbdInteractiveAuthentication no` and `PermitRootLogin no`.
  - The `01-` prefix sorts before Ubuntu's `50-cloudimg-settings.conf`, and sshd keeps the first value it reads, so ours wins.
  - The script runs `sshd -t` before reloading, and removes the file again if the test fails.
- **Enables fail2ban** with an `sshd` jail.
- **Turns off rpcbind** (`rpcbind.service` and `rpcbind.socket`). Oracle's Ubuntu image runs it on `0.0.0.0:111`, and nothing here uses NFS.
- **Adds a 4 GB swap file** at `/swapfile`, only if the VM has no swap.
- **Prints a summary** and tells you if a reboot is required.

### 9.1 Run it

From the repo folder on your laptop (a checkout made after `.gitattributes` was added, so the script has LF line endings):

```bash
scp scripts/bootstrap-vm.sh iltiam:~
ssh iltiam
sudo bash ~/bootstrap-vm.sh
```

**What you should see:** sections starting with `==>`, each with `ok:` lines, and at the end a summary similar to:

```
hostname:  iltiam-1
arch:      aarch64
cpus:      2
timezone:  Asia/Riyadh
               total        used        free      shared  buff/cache   available
Mem:            11Gi       ...
Swap:          4.0Gi       ...
...
Docker version 29.x.x, build ...
Docker Compose version v5.x.x
REBOOT REQUIRED. ...        (or: No reboot required. ...)
```

### 9.2 Check SSH before you close anything

> **Keep the SSH session where you ran the script open.** Open a **second terminal** on your laptop and run `ssh iltiam`. Only when that new login works may you close the first one. If the new login fails, fix it from the still-open session, for example `sudo rm /etc/ssh/sshd_config.d/01-iltiam.conf`. Locking yourself out means recovering through Oracle's serial console, which is slow.

In the second terminal, also check that passwords are refused:

```bash
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password iltiam
# expected: ubuntu@<PUBLIC_IP>: Permission denied (publickey).
```

### 9.3 Reboot if asked (gotcha 4)

After `apt upgrade`, a new kernel often needs a reboot, and the script says `REBOOT REQUIRED`. Run:

```bash
sudo reboot
```

Wait about 1 minute, then `ssh iltiam` again. **Log out and back in in any case**, so that the `docker` group applies to `ubuntu` (otherwise `docker ps` says "permission denied").

### 9.4 Stay on Ubuntu 24.04 LTS

**Never run `do-release-upgrade`.** The login banner may announce a newer Ubuntu release; ignore it. The stack, the images and this runbook are built and tested on 24.04 LTS, and a release upgrade on the only server can break Docker, the kernel or SSH with no second machine to fall back to. Security fixes arrive automatically through unattended-upgrades; run `sudo apt update && sudo apt upgrade` by hand about once a month.

## 10. Data volume at `/srv/iltiam` (100 GB)

The boot volume has 100 GB. The other 100 GB of the free 200 GB becomes a separate data volume, which later holds the Postgres data, Redis data and model weights (Runbook 5).

### 10.1 Create and attach it (console)

1. **☰ → Storage → Block Storage → Block Volumes → Create Block Volume:**
   - Name `iltiam-data`, compartment `iltiam`, AD-1, size **100 GB**, **VPU 10** (Balanced).
   - **Create.** Wait for **Available**.
2. **Attach it from the volume page.** On some consoles the instance-side **Attach block volume** button is greyed out, so start from the volume:
   - **Block Volumes → `iltiam-data` → Attached instances → Attach to instance.**
   - Instance `iltiam-1`, access **Read/Write**.
   - **Paravirtualized**, if the dialog offers an attachment type. This needs no iSCSI commands.
   - **Device path: only if your console offers the field**, pick `/dev/oracleoci/oraclevdb`. Our dialog had no such field, and the attachment showed Device path "—".
   - **Attach.** Wait for **Attached**.

> **Do not rely on `/dev/oracleoci/*` paths when no device path was chosen.** On our VM, `/dev/oracleoci/oraclevdb` was never created, and `/dev/oracleoci/oraclevda` pointed at the **data** disk (`sdb`) instead of the boot disk, even after a reboot. Identify the disk with `lsblk` and mount it by UUID, as below. This works whether or not a device path was set.

### 10.2 Format and mount it (on the VM)

`mkfs` **erases** a disk. Steps 1 and 2 make sure you have the right disk and that it is empty.

```bash
# 1. Find the new disk: 100G, TYPE "disk", no partitions under it, no FSTYPE,
#    no mount point. Normally it is sdb; the boot disk (sda) has partitions.
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
DISK=/dev/sdb        # use the name lsblk showed

# 2. The new disk must have NO filesystem yet. Expect no output at all.
sudo blkid "$DISK"
#    If this prints anything (TYPE="ext4" ...), STOP: wrong disk, or it has data on it.

# 3. Format it (only after step 2 printed nothing).
sudo mkfs.ext4 -L iltiam-data "$DISK"

# 4. Mount it at /srv/iltiam, now and on every boot. Mount by UUID:
#    names like sdb can change between boots, the UUID cannot.
sudo mkdir -p /srv/iltiam
UUID=$(sudo blkid -s UUID -o value "$DISK")
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID /srv/iltiam ext4 defaults,_netdev,nofail 0 2" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a

# 5. Check.
findmnt /srv/iltiam
df -h /srv/iltiam
```

**What you should see:**
- `lsblk` (step 1): `sda` about 100G with its partitions (`/`, `/boot`, `/boot/efi`), and `sdb` 100G with nothing under it.
- `findmnt` (step 5): `/srv/iltiam` with `ext4`.
- `df -h`: about **98G** of size.

Don't paste the UUID itself into issues or the repo.

`nofail` means the VM still boots if the volume is ever detached. Your services would then start without their data, which is why the verification below checks the mount after a reboot.

Then reboot once more (`sudo reboot`) and check `findmnt /srv/iltiam` again.

## 11. Verification checklist

Run these on the VM after the final reboot unless the row says otherwise. Every row must match before the issue is closed.

The **Verified** column records when each row last passed on `iltiam-1`.

| # | Check | Command | Expected | Verified |
|---|---|---|---|---|
| 1 | Architecture | `uname -m` | `aarch64` | 2026-10-27 |
| 2 | CPUs | `nproc` | `2` | 2026-10-27 |
| 3 | Memory and swap | `free -h` | `Mem:` total about `11Gi`; `Swap:` `4.0Gi` | 2026-10-27 |
| 4 | Swap file | `swapon --show` | `/swapfile  file  4G` | 2026-10-27 |
| 5 | Boot disk | `df -h /` | Size about `96G` | 2026-10-27 |
| 6 | Data volume mounted by UUID, after reboot | `findmnt /srv/iltiam` and `grep /srv/iltiam /etc/fstab` | `findmnt`: one line, `/srv/iltiam`, the data disk (normally `/dev/sdb`), `ext4`. fstab: `UUID=<UUID> /srv/iltiam ext4 defaults,_netdev,nofail 0 2`, with no `/dev/oracleoci/...` path | 2026-10-27 |
| 7 | Hostname survives reboot | `hostnamectl --static` | `iltiam-1` | 2026-10-27 |
| 8 | Timezone | `timedatectl` | `Time zone: Asia/Riyadh (+03, +0300)` | 2026-10-27 |
| 9 | Docker | `docker --version` | `Docker version 29.x` or newer | 2026-10-27 |
| 10 | Compose | `docker compose version` | `Docker Compose version v5.x` or newer | 2026-10-27 |
| 11 | Docker works without sudo | `docker run --rm hello-world` | `Hello from Docker!` | 2026-10-27 |
| 12 | Groups | `id ubuntu; id deploy` | Both lists include `docker` | 2026-10-27 |
| 13 | `deploy` has no password | `sudo passwd -S deploy` | Second field `L` (locked) | 2026-10-27 |
| 14 | Auto updates | `systemctl is-enabled unattended-upgrades` | `enabled` | 2026-10-27 |
| 15 | fail2ban | `sudo fail2ban-client status sshd` | `Status for the jail: sshd` | 2026-10-27 |
| 16 | SSH settings | `sudo sshd -T \| grep -Ei '^(passwordauthentication\|kbdinteractiveauthentication\|permitrootlogin) '` | All three lines end in `no` | 2026-10-27 |
| 17 | Password login refused (**from the laptop**, a second terminal) | `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password iltiam` (without the alias: `... ubuntu@<PUBLIC_IP>`) | `ubuntu@<PUBLIC_IP>: Permission denied (publickey).` | 2026-10-27 |
| 18 | Only SSH listens publicly | `sudo ss -tlnp` | On a public address only `0.0.0.0:22` and `[::]:22`, with **no `:111`** (rpcbind off). Anything else only on `127.0.0.x` (e.g. `127.0.0.53:53`) | 2026-10-27 |
| 19 | No pending reboot | `ls /var/run/reboot-required` | `No such file or directory` | 2026-10-27 |
| 20 | Script is idempotent | `sudo bash ~/bootstrap-vm.sh` (second run) | Only `ok: already ...` lines, then the summary | 2026-10-27 |
| 21 | Shape (console) | Compute → Instances → `iltiam-1` | `VM.Standard.A1.Flex`, 2 OCPU, 12 GB, Always Free-eligible | 2026-10-27 |
| 22 | Region (console) | Top bar region menu | Home region **Saudi Arabia Central (Riyadh)** | 2026-10-27 |
| 23 | MFA (console) | Sign out and back in | Asks for the authenticator code (both admins) | 2026-10-27 |
| 24 | Budget (console) | Billing → Budgets → `iltiam-monthly-budget` | 10 USD monthly, root compartment, 5 alert rules, 2 recipients | 2026-10-27 |
| 25 | Ingress (console) | Default Security List → Ingress rules (compartment filter **root** if the VCN was moved, section 6.4) | TCP 22 from `0.0.0.0/0` plus the two default ICMP rules; nothing else, no 80/443 | 2026-10-27 |
| 26 | No charges (console, **one week later**) | Billing & Cost Management → Cost Analysis | $0.00 for the last 7 days | Due 2026-11-03 |

Record the results as a comment on the issue: pass/fail per row and the versions. No IPs, OCIDs or emails.

## 12. Security notes

- **Keys:** the private SSH key stays on the laptop, protected by a passphrase. Only `iltiam_oci.pub` is on the VM. The repo's `.gitignore` blocks common key file names, but the rule is simply: never `git add` anything from `~/.ssh` or `~/.oci`.
- **Inbound traffic:** only TCP 22 (rpcbind on port 111 is turned off by the script), with key-only login, no root login, and fail2ban banning brute-force sources. There are **no public 80/443** rules. The apps are reached through the Cloudflare Tunnel (Runbook 3), which connects outbound from the VM, so no web port is ever opened.
- **Host firewall:** Oracle's Ubuntu image ships iptables rules (`/etc/iptables/rules.v4`) that also allow only port 22 in. Leave them; don't flush them, and don't open ports there.
- **Updates:** unattended-upgrades installs security fixes daily. Reboot when the login banner says `*** System restart required ***`, at a quiet time.
- **Accounts:** two administrators, both with MFA. Remove the OCI API key once you no longer need the CLI (section 7).
- **Placeholders only:** this runbook, issues and PRs use `<PUBLIC_IP>` and the other placeholders, never real values.

## 13. Idle reclamation

Oracle may **reclaim an Always Free instance that is idle for 7 days**: CPU p95, network and (for A1) memory all under 20 %.

- Once staging and production run (Runbook 5), memory stays well above 20 %.
- **Until then the VM is idle.** Start the next work on it (AI-12, the ARM benchmark) within a week, and keep the console's notification emails on.
- Monitoring (DEP#10) alerts if the instance stops.

## 14. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| "Out of host capacity" when creating | Section 7 |
| `ssh: connect to host ... port 22: Connection timed out` | No public IP (gotcha 2, section 6.2), wrong IP in `~/.ssh/config`, or the TCP 22 ingress rule is missing (section 5.2) |
| `Permission denied (publickey)` with your key | Wrong user (it is `ubuntu`) or wrong key. Try `ssh -v -i ~/.ssh/iltiam_oci ubuntu@<PUBLIC_IP>` and look for "Offering public key" |
| `bash: $'\r': command not found` from the script | Windows line endings. Copy it from a checkout that includes `.gitattributes`, or on the VM run `sed -i 's/\r$//' ~/bootstrap-vm.sh` |
| `Could not get lock /var/lib/dpkg/lock-frontend` | unattended-upgrades is running (common in the first minutes after boot). Wait 5 minutes and run the script again |
| `sudo: unable to resolve host iltiam-1` | The `/etc/hosts` line is missing. Run the script again |
| Hostname back to the VNIC name after reboot | `/etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg` is missing. Run the script again |
| `permission denied while trying to connect to the Docker daemon socket` | Log out and back in (group change), or reboot |
| fail2ban fails to start | `sudo journalctl -u fail2ban -n 50`. Make sure packages are up to date (the first Ubuntu 24.04 fail2ban build failed on Python 3.12; the fix comes through updates) |
| `/srv/iltiam` empty or not mounted after reboot | `findmnt /srv/iltiam`; check the volume is **Attached** in the console; `sudo mount -a` and read the error; compare the `UUID=` line in `/etc/fstab` with `sudo blkid` |
| **Attach block volume** greyed out on the instance page | Attach from the volume page instead (section 10.1) |
| `/dev/oracleoci/oraclevdb` missing, or `oraclevda` points at the data disk | Expected when the attachment has no device path (Device path "—"). Ignore `/dev/oracleoci/*`: find the disk with `lsblk` and mount by UUID (section 10.2) |
| `sshd -t failed` from the script | The script removed its drop-in, so SSH is unchanged. Run `sudo sshd -t` to see the error |
| Instance stopped or gone | Idle reclamation (section 13), or an over-limit shape at trial end (section 6.3). Check the console's notifications and the instance's work requests |

## 15. What comes next

- **AI-12** (iltiam/iltiam-ai-service#142): the ARM go/no-go benchmark runs on this VM next.
- **[Runbook 2](02-cloudflare-dns-tls.md):** Cloudflare account, DNS and TLS (DEP-01).
- **Runbook 3:** Cloudflare Tunnel, the only way web traffic reaches the VM (DEP#9).
- **Runbook 5:** the staging and production Compose projects on `/srv/iltiam` (DEP#2).
- **Runbook 8:** object storage and Vault keys (DEP-02).
