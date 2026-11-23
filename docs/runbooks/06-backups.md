# Runbook 6: nightly encrypted backups, volume backups and a weekly restore test (free, in Riyadh)

- **Issue:** iltiam/iltiam-deployment#8 (DEP#8). SRS NFR-REL-02 and NFR-REL-04: a backup every day, a restore within 4 hours, a restore test every week.
- **Who:** someone who can sign in to the OCI console as an administrator, log in to `iltiam-1` as `ubuntu` (`ssh iltiam`, Runbook 1), set GitHub Environment secrets on `iltiam-deployment`, and write to the Bitwarden collection **ILTIAM escrow**.
- **Time:** about 1 hour 30 minutes for staging (sections 3 to 9), then one night for the first backup and one Friday for the first restore test. Production (section 11) takes about 30 minutes more, when production runs (#36).
- **Result:** every night each environment's two databases are dumped, encrypted with `age` and uploaded to its private `-backups` bucket in Riyadh. 14 daily and 8 weekly copies are kept. Every Friday the newest copy is restored into a throwaway database and checked. A missing backup or a failed restore test emails the team. Each week the data volume also gets an OCI volume backup, and each month the boot volume. Everything stays within the free tier.
- **Restoring for real:** [06-restore.md](06-restore.md).

> **This repository is public.** Never paste a key, a ping URL, the namespace, an OCID or a backup's content into this runbook, an issue, a PR, a commit or a chat. The scripts print names, sizes, counts and times only.

## As built

Filled in when the steps are done. Names and dates only.

| Item | Value |
|---|---|
| Lifecycle rules on `iltiam-staging-backups` (section 3) | |
| Backup user, group and policy, staging (section 4) | |
| Dead-man checks, staging (section 5) | |
| Timers on the VM, staging (section 6) | |
| age key pair, staging (section 7), escrowed in Bitwarden | |
| Backup settings in GitHub, staging (section 8) | |
| First nightly backup, staging (section 9) | |
| First restore test, staging (section 9) | |
| Volume backup policies (section 10) | |
| Missing-backup alert tested (section 12) | |
| Production (section 11) | after #36 |
| Restore rehearsal ([06-restore.md](06-restore.md), section 5) | |

## 1. How it works

```
02:30 every night (staging; production 02:15), systemd timer on iltiam-1, as deploy
  scripts/backup.sh <env>
    pg_dump -Fc iltiam, iltiam_ai ─▶ checked ─▶ + roles (no passwords), row counts, SHA256SUMS
      ─▶ one tar, encrypted with age (the environment's public key) ─▶ plain files deleted at once
      ─▶ iltiam-<SHORT>-backups/daily/<env>-<UTC time>.tar.age     (Fridays: also weekly/)
      ─▶ ping "success" to the dead-man check, status file for Runbook 7 (#10)
    any failure: ping "fail", nothing half-written stays anywhere

Fridays 04:00 (staging; production 04:30)
  scripts/restore-test.sh <env>
    newest daily/ copy (at most 26 h old) ─▶ decrypt (the private key) ─▶ checksums
      ─▶ a throwaway Postgres container on the environment's internal network
      ─▶ both databases restored, every table there, no table that had rows is empty
      ─▶ manage.py check against it (backend image) ─▶ container and files removed ─▶ ping

Lifecycle rules on the bucket: daily/ deleted after 14 days, weekly/ after 56 days (8 weekly copies).
The backup user can create and read objects in its own bucket only. It can't delete or overwrite one.

Weekly and monthly, OCI itself: a volume backup of iltiam-data (keep 2) and of the boot volume (keep 1).
```

**Why on the VM, with systemd, and not a `backup` container:**
- A container would need its own image, built and published from this repository, with pg_dump, age and an S3 client, and it would stay in memory all day on the 12 GB VM.
- The timers run the same `compose exec postgres pg_dump` as the pre-deploy backup ([Runbook 9](09-cd-staging.md)). They use no memory between runs, and they need only the packages `age` and `rclone`.

**Where it all stays:** the dumps are made, restored and tested on the VM, and stored only in the Riyadh bucket ([restore-location.md](../privacy/restore-location.md)). No workflow ever touches one, and `scripts/check-env.sh` checks that. The dead-man checks (section 5) receive a bare HTTP request at the end of each run, never any data.

**What is where:**

| Data | Backed up by | Kept |
|---|---|---|
| Postgres `iltiam` and `iltiam_ai` | the nightly backup (this runbook) | 14 daily, 8 weekly |
| The data volume `iltiam-data` (Postgres, Redis, weights) | OCI volume backup (section 10) | 2 weekly |
| The boot volume | OCI volume backup (section 10) | 1 monthly |
| Photos, masks, PDFs, exports | object versioning, 30 days ([Runbook 8](08-object-storage.md), section 8) | as Runbook 8 says |
| Env files, Redis, weights | nothing: the next deploy, Redis itself and `weights-init` rebuild them ([Runbook 5](05-compose-stack.md), section 12) | |

**How much data can be lost:** at most a day (the time since the last nightly backup). A whole lost volume is restored from its volume backup (at most a week old), then from the newest nightly dumps ([06-restore.md](06-restore.md)).

## 2. Before you start

1. This runbook's PR is merged, and **staging has been deployed since**, so the VM's clone has `scripts/backup.sh` and the deploy writes `backup.env`. Check on the VM as `deploy`:

   ```bash
   ls /srv/iltiam/repo/scripts/backup.sh /srv/iltiam/env/staging/backup.env
   ```

   **What you should see:** both paths, no error. Until the backup settings are set (section 8), `backup.env` is empty: that's expected.
2. **Free space:** the backups bucket has a budget of **3 GB** for both environments ([Runbook 8](08-object-storage.md), section 2). Section 9 checks the size of the first backup against it.
3. A phone or laptop with Bitwarden, for the private key (section 7).

## 3. Lifecycle rules on the backups bucket (once per environment)

The `-backups` buckets have no versioning, so a deleted backup is really gone. These rules do the deleting: the backup user can't.

1. **☰ → Storage → Object Storage & Archive Storage → Buckets**, compartment `iltiam` → `iltiam-staging-backups` → **Lifecycle Policy Rules** (under Resources) **→ Create Rule**, three times:

   | Name | Target | Lifecycle action | Days | Object name filters → Include prefixes |
   |---|---|---|---|---|
   | `delete-daily` | **Objects** | Delete | **14** | `daily/` |
   | `delete-weekly` | **Objects** | Delete | **56** | `weekly/` |
   | `abort-unfinished-uploads` | **Uncommitted multipart uploads** | Delete | **1** | (none) |

2. **What you should see:** three rules, all **Enabled**.

- **Why these numbers:** 14 days keeps the 14 newest nightly copies. 56 days keeps 8 Friday copies.
- **If creating a rule fails** with a permissions message: [Runbook 8](08-object-storage.md), section 6, line 2 is missing.
- **Check the prefixes twice.** A rule without a prefix would delete every backup after 14 days, the weekly ones included.

## 4. The backup user (once per environment)

The same steps as the backend's storage user ([Runbook 8](08-object-storage.md), sections 9.1 to 9.5), with other names and a smaller policy.

1. **Group:** **☰ → Identity & Security → Domains → Default domain → User management → Groups → Create group.** Name `iltiam-staging-backup` → **Create.**
2. **User:** **User management → Users → Create user.** Last name and username `iltiam-staging-backup`, email `<SERVICE_USER_EMAIL>` (untick **Use the email address as the username**), group `iltiam-staging-backup` → **Create.** Ignore the activation email: this user never signs in.
3. **Capabilities:** the user **→ Edit user capabilities:** tick **only Customer secret keys** → **Save changes.**
4. **Policy:** **☰ → Identity & Security → Policies**, compartment `iltiam` **→ Create Policy.** Name `iltiam-backup-staging`, **Show manual editor**, paste (each statement is one line):

   ```
   Allow group 'Default'/'iltiam-staging-backup' to read buckets in compartment iltiam where target.bucket.name='iltiam-staging-backups'
   Allow group 'Default'/'iltiam-staging-backup' to manage objects in compartment iltiam where all {target.bucket.name='iltiam-staging-backups', any {request.permission='OBJECT_INSPECT', request.permission='OBJECT_READ', request.permission='OBJECT_CREATE'}}
   ```

   **Create.**
5. **Key:** the user **→ Customer secret keys → Generate secret key**, name `staging-backup-<YYYY-MM>`. **The secret is shown once.** Keep the dialog open, or keep the value only in your clipboard, until section 8, step 1 asks for it. Then **Close.** The access key stays visible in the list.

**What this allows:** list, read and create objects in `iltiam-staging-backups`, and nothing else. **What it doesn't allow:** deleting or overwriting a backup, which is why someone who steals the key from the VM still can't destroy the old backups, and any other bucket, the backend's buckets included. Write the bucket name out in full: never a pattern ([Runbook 8](08-object-storage.md), section 9.4, says why).

## 5. Dead-man checks (once, free)

A dead-man check emails the team when an expected ping **doesn't** arrive: the backup didn't run, the VM is off, or the job failed. That is the "missing nightly backup" alert of this issue, until Runbook 7 (#10) adds its own alert on the status file.

We use [healthchecks.io](https://healthchecks.io) on its free plan (20 checks). It receives an HTTP request with nothing in it from the VM at the end of each run: no data, no names.

1. Sign up at **healthchecks.io** with the team mailbox ([docs/secrets.md](../secrets.md), section 3), and turn on two-factor sign-in (**Account Settings → Two-factor Authentication**). It is a provider account like the others in that section: the team mailbox can always reset it, so it doesn't go into Bitwarden.
2. **Integrations:** the team mailbox's **Email** integration is there by default. Add each teammate who should be alerted.
3. **Add Check**, twice, with **Cron** schedules (time zone **Asia/Riyadh**):

   | Name | Schedule | Grace time | Tags |
   |---|---|---|---|
   | `iltiam-staging-nightly` | `30 2 * * *` | 2 hours | `staging backup` |
   | `iltiam-staging-restore-test` | `0 4 * * 5` | 3 hours | `staging backup` |

4. On each check, copy its **Ping URL** (`https://hc-ping.com/<uuid>`) for section 8. **Treat it like a secret:** anyone who has it could ping the check and hide a missing backup.

**What you should see:** both checks listed as **New** (grey) until their first ping.

## 6. Install the timers on the VM (once per environment)

On the VM as `ubuntu`:

```bash
sudo bash /srv/iltiam/repo/scripts/install-backup-timers.sh staging
```

**What you should see:** `ok:` lines for the packages (`age` and `rclone`), the folders and the units, and then the next runs:

```
NEXT                        LEFT   LAST PASSED UNIT                              ACTIVATES
Mon 2026-11-24 02:30:00 +03 ...    -    -      iltiam-backup-staging.timer       iltiam-backup@staging.service
Fri 2026-11-28 04:00:00 +03 ...    -    -      iltiam-restore-test-staging.timer iltiam-restore-test@staging.service
```

- It is safe to run again. `--remove staging` stops and removes that environment's timers.
- The units run the scripts as `deploy`, from `/srv/iltiam/repo/scripts`: the commit the last deploy checked out.
- **Until section 8 is done,** a run fails with `missing from backup.env: ...`. That does no harm, but finish sections 7 and 8 the same day.

## 7. The age key pair (once per environment)

`age` encrypts each backup to a **public key** (`age1…`). Only the matching **private key** (`AGE-SECRET-KEY-1…`) decrypts it. The nightly backup needs only the public key. The restore test, and a real restore, need the private one.

1. On the VM as `ubuntu`, in a terminal nobody else can see:

   ```bash
   age-keygen 2>/dev/null; echo
   ```

   It prints three lines: a `# created:` line, a `# public key: age1…` line and the private key `AGE-SECRET-KEY-1…`. **Nothing is written to a file.**
2. **Bitwarden first:** in the collection **ILTIAM escrow**, create a **Secure Note** named `age backup key staging`. Paste all three lines. **Save.** Without this copy, losing the GitHub secret makes every staging backup useless.
3. Keep the terminal open for section 8, then run `clear` there.

**Never** put the private key in a file, a chat, an issue or a commit. Each environment has its own key pair: never reuse staging's for production.

## 8. Put the values into GitHub (once per environment)

From your clone, in Git Bash. Each `read` takes a value without showing it: paste, Enter.

```bash
ENV=staging; REPO=iltiam/iltiam-deployment
read -rs -p "backup access key: " v; echo; printf '%s' "$v" | gh secret set BACKUP_STORAGE_ACCESS_KEY --env "$ENV" -R "$REPO"
read -rs -p "backup secret key: " v; echo; printf '%s' "$v" | gh secret set BACKUP_STORAGE_SECRET_KEY --env "$ENV" -R "$REPO"
read -rs -p "age private key (AGE-SECRET-KEY-1...): " v; echo; printf '%s' "$v" | gh secret set BACKUP_AGE_IDENTITY --env "$ENV" -R "$REPO"
read -rs -p "nightly ping URL: " v; echo; printf '%s' "$v" | gh secret set BACKUP_PING_URL --env "$ENV" -R "$REPO"
read -rs -p "restore-test ping URL: " v; echo; printf '%s' "$v" | gh secret set BACKUP_RESTORE_PING_URL --env "$ENV" -R "$REPO"
read -r -p "age public key (age1...): " v; gh variable set BACKUP_AGE_RECIPIENT --env "$ENV" --body "$v" -R "$REPO"
unset v; clear
```

`STORAGE_ENDPOINT_URL` and `STORAGE_REGION` are already set for the backend ([Runbook 8](08-object-storage.md), section 11). The deploy puts them into `backup.env` as well.

**What you should see:** five `✓ Set Actions secret …` lines and one `✓ Created variable BACKUP_AGE_RECIPIENT …` line. No value is printed.

**Then deploy staging**, so `backup.env` gets the values. The next automatic deploy does it, or start one with the `deploy` workflow ([AGENTS.md](https://github.com/iltiam/iltiam-deployment/blob/main/AGENTS.md), "Deploying staging"). Check on the VM as `deploy`:

```bash
grep -c '^BACKUP_' /srv/iltiam/env/staging/backup.env
```

**What you should see:** `6`. The command prints a count, never a value.

## 9. The first backup and restore test, by hand

On the VM as `ubuntu`:

```bash
sudo systemctl start iltiam-backup@staging.service
journalctl -u iltiam-backup@staging.service -n 30 --no-pager -o cat
```

**What you should see** (sizes differ):

```
==> nightly backup (staging)
==> dump
    iltiam: 2.1M, 61 tables, 4210 rows
    iltiam_ai: 1.3M, 9 tables, 820 rows
==> encrypt
    staging-20261123T183012Z.tar.age (3.4M), decrypts
==> upload to iltiam-staging-backups
    daily/staging-20261123T183012Z.tar.age: 3561472 bytes
Backup: staging done (staging-20261123T183012Z.tar.age).
```

The `iltiam-staging-nightly` check turns **Up** (green).

**The size budget:** 22 copies of each environment are kept (14 daily and 8 weekly). Multiply the backup's size by 22: staging's total and production's together must stay under **3 GB**. If they won't, say so on #8: the number of weekly copies is the first thing to lower.

Then the restore test:

```bash
sudo systemctl start iltiam-restore-test@staging.service
journalctl -u iltiam-restore-test@staging.service -n 30 --no-pager -o cat
```

**What you should see:**

```
==> restore test (staging)
==> the newest backup
    staging-20261123T183012Z.tar.age, 0 hours old
    decrypted, checksums match (16.15)
==> restore into a throwaway database
    iltiam: 61 tables, 4210 rows, restored in 9 s
    iltiam_ai: 9 tables, 820 rows, restored in 3 s
==> manage.py check against the restored database
    System check identified no issues (0 silenced).
Restore test: staging passed (staging-20261123T183012Z.tar.age).
```

The `iltiam-staging-restore-test` check turns **Up**. Write the date and both row counts in the As built table and in the verification checklist (section 14, rows 6 and 7).

## 10. Volume backups (once, both environments share the volumes)

Always Free includes **5 volume backups** in all, in the home region. These two policies keep 3 (2 weekly, 1 monthly), which leaves room for the moment when a new backup is taken before the oldest one expires.

1. **☰ → Storage → Block Storage → Backup Policies**, compartment `iltiam` **→ Create Backup Policy.** Name `iltiam-data-weekly`. **Add Schedule:** Schedule type **Weekly**, Backup type **Full**, day **Friday**, hour **01:00**, time zone **Regional Data Center Time**, retention **2 weeks**. **Create Backup Policy.** Don't add a cross-region copy (it isn't free, and it would leave Riyadh).
2. Again, name `iltiam-boot-monthly`: Schedule type **Monthly**, Backup type **Full**, day of the month **1**, hour **01:30**, time zone **Regional Data Center Time**, retention **1 month**.
3. **Block Storage → Block Volumes →** `iltiam-data` **→ Backup policy: Assign** (on some consoles **Edit → Backup policy**) → `iltiam-data-weekly` → **Assign.**
4. **Block Storage → Boot Volumes →** `iltiam-1 (Boot Volume)` → the same, with `iltiam-boot-monthly`.

**What you should see:** each volume's page shows its policy. After the first Friday, **Block Volume Backups** lists one backup of `iltiam-data`, **Available**.

- **Never take a manual volume backup** while these policies run, unless you delete an old one first: a sixth backup fails.
- **A volume backup is crash-consistent:** it is like pulling the power. Postgres recovers from that by itself at start. The nightly dumps remain the main backup, and the volume backup is for losing the whole volume.
- **Restoring one makes a new 100 GB volume.** That's over the free 200 GB unless the broken volume is deleted first ([06-restore.md](06-restore.md), section 3).

## 11. Production (when production runs, #36)

Sections 3 to 9 again, with:
- bucket `iltiam-prod-backups`; group, user and policy `iltiam-prod-backup` and `iltiam-backup-prod`, with `iltiam-prod-backups` in both statements; key name `prod-backup-<YYYY-MM>`;
- dead-man checks `iltiam-production-nightly` (`15 2 * * *`) and `iltiam-production-restore-test` (`30 4 * * 5`);
- `sudo bash /srv/iltiam/repo/scripts/install-backup-timers.sh production`;
- a new key pair, escrowed as `age backup key production`;
- `ENV=production` in section 8. **Production refuses to deploy without these settings** (they are `prod-required` in `env/backup.env.example`). On purpose: production takes no real patient data before its backups work ([go-live checklist](../go-live-checklist.md)).

## 12. Test the missing-backup alert (once, on staging)

The acceptance criteria want proof that a missing backup raises an alert.

1. In the afternoon, on the VM as `ubuntu`: `sudo systemctl stop iltiam-backup-staging.timer`.
2. The next morning, after 04:30 (02:30 plus the 2-hour grace), the team mailbox has an email from healthchecks.io: `iltiam-staging-nightly is DOWN`. Write its time in section 14, row 9.
3. `sudo systemctl start iltiam-backup-staging.timer`, then `sudo systemctl start iltiam-backup@staging.service`. The check turns **Up**, and a second email says so.
4. **The failure path:** temporarily set a wrong `BACKUP_AGE_RECIPIENT` variable, deploy, and start the backup by hand. It fails with `BACKUP_AGE_RECIPIENT is not the public key of BACKUP_AGE_IDENTITY`, and the check turns **Down** straight away. Put the right value back and deploy.

## 13. Day to day

| Task | How (on the VM as `ubuntu` unless said) |
|---|---|
| Did last night's backup work? | `journalctl -u iltiam-backup@staging.service --since yesterday --no-pager -o cat \| tail -n 5`, or the check on healthchecks.io |
| When do they run next? | `systemctl list-timers 'iltiam-*'` |
| Which backups exist? | as `deploy`: `/srv/iltiam/repo/scripts/backup-fetch.sh staging --list` |
| Space used | OCI console: the bucket's **Approximate size**. [Runbook 8](08-object-storage.md)'s 70 % alarm covers all buckets together |
| Status for monitoring | `/srv/iltiam/backups/status/<env>-nightly.prom` and `<env>-restore-test.prom`; Runbook 7 (#10) mounts that folder into node-exporter |
| Pause backups (e.g. during a migration by hand) | `sudo systemctl stop iltiam-backup-staging.timer`; **start it again the same day**: the dead-man check emails otherwise |
| Rotate the backup user's key (yearly, with the storage keys) | section 4, step 5 with a new name, then section 8 for the two key secrets, deploy, delete the old key ([docs/secrets.md](../secrets.md), section 6.4) |

**Never rotate the age key pair** as a routine: backups encrypted to the old public key need the old private key, for as long as they are kept (56 days). If the private key leaks, make a new pair (section 7), set both values (section 8), deploy, and **keep the old private key in Bitwarden** under a dated name until the last old backup has expired.

## 14. Verification checklist

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | CI | the PR's checks | `scripts/ci-local.sh --full` PASS: shellcheck of the backup scripts, the backup checks of `check-env.sh`, the workflow rules | this PR | |
| 2 | Lifecycle rules | section 3 | 3 rules Enabled on `iltiam-staging-backups`, prefixes as in the table | console | |
| 3 | Backup user | section 4 | Customer secret keys only; policy with the exact bucket name, no delete, no overwrite | console | |
| 4 | Timers | section 6 | `systemctl list-timers 'iltiam-*'` lists both staging timers | VM | |
| 5 | age key escrowed | section 7 | Bitwarden note `age backup key staging` | Bitwarden | |
| 6 | First nightly backup | section 9 | `Backup: staging done`; check Up; size × 22 within budget | VM | |
| 7 | Restore test by hand | section 9 | `Restore test: staging passed`, with the row counts | VM | |
| 8 | Two scheduled Friday restore tests in a row (AC 1) | `journalctl -u iltiam-restore-test@staging.service --since -15d -o cat \| grep 'Restore test:'` | two `passed` lines, a week apart | two Fridays | |
| 9 | Missing backup alerts (AC 3) | section 12 | the DOWN email, its time | the next morning | |
| 10 | Volume backups | section 10 | policies assigned; one `iltiam-data` backup Available after a Friday; at most 5 backups in all | console | |
| 11 | Rehearsal under 4 hours (AC 2) | [06-restore.md](06-restore.md), section 5 | the time | after the Dec 1 demo | |
| 12 | Billing still $0 (AC 3) | **Billing & Cost Management → Cost Analysis**, a week after section 10 | $0.00 | console | |
| 13 | Production | section 11 | rows 2 to 10 for production | after #36 | |

**Record the results on issue #8:** pass or fail per row, with the date and the row counts. **Never include** a key, a ping URL, the namespace or an OCID.

## 15. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `missing from backup.env: …` | Those settings aren't in the GitHub Environment yet, or staging wasn't deployed since. Section 8 |
| `BACKUP_AGE_RECIPIENT is not the public key of BACKUP_AGE_IDENTITY` | The two values come from different key pairs. Take both from the Bitwarden note again (section 8) and deploy |
| `rclone` errors with `SignatureDoesNotMatch` or `403` | A new key takes a few minutes to reach every OCI server. Otherwise the policy's bucket name has a typo (section 4, step 4) |
| `another backup of staging is running` | A run by hand and the timer at the same time. Wait for the first one to finish (`systemctl status iltiam-backup@staging.service`) |
| `only … MB free on /srv/iltiam` | The data volume is nearly full. Look at `df -h /srv/iltiam` and at Docker's images (`docker system df`) before anything else |
| `postgres is not running in staging` | The stack is down: [Runbook 5](05-compose-stack.md), section 13 |
| Restore test: `the newest backup … is N hours old` | The nightly backup didn't run or failed: read its journal (section 13). Fix it, run it by hand, then run the restore test again |
| Restore test: `missing table` or `empty table` | The backup is incomplete or the restore failed halfway. **Don't trust that backup.** Run a backup by hand and test again. If it repeats, keep the journal and raise it on #8 |
| Restore test: `manage.py check failed` | The last 20 lines are in the journal. A newer backend may expect a migration the backup doesn't have yet (a deploy after the dump). Run the backup and the test again by hand: both should then pass |
| Restore test: `network iltiam-staging_internal not found` | Staging isn't deployed. Deploy it, then run the test |
| A check stays **Down** although the journal says `done` | The ping didn't go through (the journal says `note: the success ping did not go through`). Check the URL secret (section 8) and that the VM reaches `hc-ping.com` |

## 16. Security and privacy

- **Encrypted twice:** each backup is encrypted with the environment's age key before it leaves the VM. Object Storage then encrypts it again with the environment's Vault key ([Runbook 8](08-object-storage.md), section 5). Someone with a copy of the bucket still can't read a backup.
- **The private key sits in GitHub, in `backup.env` on the VM, and in Bitwarden.** Someone who controls the VM already has the live database, so the key there adds no new risk. It protects the bucket and its copies.
- **The backup user can't delete or overwrite.** A stolen key, or a compromised VM, can't destroy the old backups. Only the lifecycle rules delete them, on schedule.
- **Plain dumps exist only for the length of a run,** in a folder of mode 700 on the data volume. Every script removes it on any exit. [`scripts/backup-fetch.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/backup-fetch.sh) is the exception, for a real restore, and [06-restore.md](06-restore.md) says when to delete what it leaves.
- **Riyadh only:** made, kept, restored and tested in OCI Riyadh ([restore-location.md](../privacy/restore-location.md)). The optional copy in Jeddah of ADR-0004 isn't set up. If it ever is, it goes into the [ROPA](../privacy/ropa.md) and restore-location.md first.
- **Retention:** 14 daily and 8 weekly copies, so a deleted patient's data is gone from the backups 56 days after the deletion at most ([retention.md](../privacy/retention.md), row 18).

## 17. What comes next

- **Runbook 7 (#10):** node-exporter reads `/srv/iltiam/backups/status/`, with an alert when `iltiam_backup_last_success_timestamp_seconds{job="nightly"}` is older than 26 hours and a Grafana panel for backup age and size.
- **#36:** section 11 for production.
- **#19 (Runbook 10):** a release takes its own database backup on the day. With this runbook done, that is a second copy, not the only one.
