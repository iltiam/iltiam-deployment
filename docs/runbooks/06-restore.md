# Runbook 6, part 2: restoring from a backup (and the timed rehearsal)

- **Issue:** iltiam/iltiam-deployment#8. **Target:** the environment works again within **4 hours** (SRS NFR-REL-04), and loses at most the time since the last nightly backup (at most a day).
- **Who:** someone who can log in to `iltiam-1` as `ubuntu` (`ssh iltiam`, Runbook 1). For section 3, also an OCI console administrator.
- **The backups:** [06-backups.md](06-backups.md) makes them. This page uses them.

> **A restore overwrites the live database.** Everything written since the backup is lost. Before you start: say so in the team chat, write down the time, and keep a log of each step's time (section 5 needs it).

> **Riyadh only.** Fetch, decrypt and restore on the VM. Never download a backup to a laptop or a runner ([restore-location.md](../privacy/restore-location.md)).

## 1. Which case is it?

| What happened | Go to |
|---|---|
| The VM and the stack run, but data in a database is wrong or lost (a bad migration, a deleted table, a bug) | section 2: restore that environment's databases from a nightly backup |
| The data volume `iltiam-data` is lost or corrupt, or `/srv/iltiam` won't mount | section 3: the volume from its weekly volume backup, then section 2 |
| The whole VM is lost (deleted, reclaimed, won't boot) | section 4: a new VM, then section 2 |

Not sure? Run the restore test first ([06-backups.md](06-backups.md), section 9): if it passes, the newest backup is good.

## 2. Restore one environment's databases from a nightly backup

Times are for staging's size today, and grow with the data.

### 2.1 Pick the backup (5 minutes)

As `deploy` (`sudo -iu deploy`):

```bash
ENV=staging   # or production
/srv/iltiam/repo/scripts/backup-fetch.sh $ENV --list
```

Choose the newest backup from **before** the damage: daily/ holds the last 14 nights, weekly/ the last 8 Fridays. Write its name down.

### 2.2 Fetch it (5 minutes)

```bash
/srv/iltiam/repo/scripts/backup-fetch.sh $ENV <name>   # without <name>: the newest daily one
```

**What you should see:** `decrypted, checksums match`, the time it was taken, and the last line `FETCHED=/srv/iltiam/backups/tmp/fetch-…/plain`. Keep that path:

```bash
F=/srv/iltiam/backups/tmp/fetch-XXXXXX/plain   # the path it printed
```

The `backend image then:` line names the backend tag that made this schema. If staging now runs a newer backend, the deploy at step 2.6 migrates the restored database forward, which is normal. If the damage came from a migration, deploy the **older** tag first (Runbook 9, rollback), so it doesn't run again.

### 2.3 Stop everything that writes (2 minutes)

```bash
iltiam() { bash /srv/iltiam/repo/scripts/compose.sh "$@"; }
iltiam $ENV stop backend-web backend-worker backend-beat ai-api ai-worker ai-beat
iltiam $ENV ps --format 'table {{.Service}}\t{{.Status}}'
```

**What you should see:** only `cloudflared`, `postgres`, `redis` (and `web`) still Up. The site shows an error page from now until step 2.6.

With `AUTO_DEPLOY` on, an automatic deploy could start the services again in the middle of this. For staging, ask an admin to set `AUTO_DEPLOY` to `false` first ([AGENTS.md](https://github.com/iltiam/iltiam-deployment/blob/main/AGENTS.md), "Deploying staging").

### 2.4 Keep a copy of what is there now (5 minutes)

Even a damaged database may still be needed, for example to copy back what was written since the backup.

```bash
mkdir -p -m 700 /srv/iltiam/backups/pre-restore
for db in iltiam iltiam_ai; do
  iltiam $ENV exec -T postgres pg_dump -U postgres -Fc $db </dev/null >/srv/iltiam/backups/pre-restore/$(date -u +%Y%m%dT%H%M%SZ)-$ENV-$db.dump
done
ls -l /srv/iltiam/backups/pre-restore/
```

### 2.5 Replace the databases (10 to 30 minutes)

For each database, drop it and create it again empty, owned by its role (as `postgres/initdb/10-iltiam.sh` does), then load the dump. `--exit-on-error` stops at the first problem.

```bash
for pair in iltiam:iltiam iltiam_ai:iltiam_ai; do
  db=${pair%%:*}; owner=${pair#*:}
  iltiam $ENV exec -T postgres psql -U postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS $db WITH (FORCE)" \
    -c "CREATE DATABASE $db OWNER $owner" \
    -c "REVOKE ALL ON DATABASE $db FROM PUBLIC" </dev/null
  iltiam $ENV exec -T postgres pg_restore -U postgres --dbname $db --exit-on-error <"$F/$db.dump" \
    && echo "restored $db"
done
```

**What you should see:** `DROP DATABASE`, `CREATE DATABASE`, `REVOKE` and `restored <db>`, twice. The roles exist already, so the restored tables keep their owners.

**If `pg_restore` stops with an error:** the database is half-loaded. Read the error, and don't start the services. Run step 2.5 again with an older backup, or put the step 2.4 copy back the same way (with that file in place of `$F/$db.dump`).

### 2.6 Start it again and check (10 minutes)

The same images as before, already on the VM: this is not a deploy, so nothing is pulled and no GHCR login is needed. The migrate one-shot runs first, as in a deploy.

```bash
iltiam $ENV run --rm backend-migrate </dev/null
iltiam $ENV up -d --wait
iltiam $ENV ps --format 'table {{.Service}}\t{{.Status}}'
bash /srv/iltiam/repo/scripts/health-check.sh staging backend   # staging only; production: the browser checks below
```

**What you should see:** the migrate run ends without an error (`No migrations to apply.` or the migrations it applied), and every service is Up and `(healthy)`. On staging the health check passes. Then, from a browser:
1. `https://staging-api.iltiamcare.com/api/ready/` (production: `api.`) answers `ready`.
2. Sign in on the web app as a test account, and open a patient whose data you know.

### 2.7 Clean up (2 minutes)

```bash
rm -rf "${F%/plain}"
ls /srv/iltiam/backups/tmp/
```

**What you should see:** no `fetch-…` folder left. Keep `pre-restore/` for 7 days, then delete it: it is a full copy of the data. Set `AUTO_DEPLOY` back if you changed it. Write on the incident (or on #8 for a rehearsal) which backup was restored and the times.

## 3. The data volume is lost: restore its volume backup

This brings back Postgres, Redis and the weights as they were at the last Friday's volume backup. Section 2 then brings the databases up to the last night.

**The free tier allows 200 GB of volumes, and both 100 GB volumes use it all.** A restored volume is a new 100 GB volume. So unless the account is upgraded, the broken volume must be **deleted first**, and there is no going back once it is gone. Decide with the team first. If the broken volume still holds data you might need, ask whether a paid month (about $2.55 for 100 GB) is acceptable for keeping both for a while.

1. **Stop the stacks**, as `ubuntu`: `sudo -iu deploy bash -c 'for e in staging production; do bash /srv/iltiam/repo/scripts/compose.sh $e down; done'`. Errors for an environment that isn't deployed are fine.
2. **Unmount:** `sudo umount /srv/iltiam`. If it says busy, `sudo systemctl stop docker` first.
3. **Console, detach:** **☰ → Storage → Block Storage → Block Volumes →** `iltiam-data` **→ Attached instances → … → Detach.** Wait for **Detached**.
4. **Console, delete:** only after the team's decision above: `iltiam-data` **→ More actions → Terminate.**
5. **Console, restore:** **Block Storage → Block Volume Backups →** the newest backup of `iltiam-data` (**Available**) **→ … → Create Block Volume.** Name `iltiam-data`, compartment `iltiam`, the same availability domain as `iltiam-1`, size 100 GB, VPU 10. **Create.** Wait for **Available** (a few minutes).
6. **Attach and mount:** [Runbook 1](01-oci-account-and-vm.md), section 10, steps for attaching from the volume page, **without formatting**. The restored file system keeps its UUID, so the existing `/etc/fstab` line mounts it: `sudo mount -a && findmnt /srv/iltiam`.
7. **Start:** run the `deploy` workflow for staging (and for production), as [AGENTS.md](https://github.com/iltiam/iltiam-deployment/blob/main/AGENTS.md) ("Deploying staging") says. Postgres replays its log at start: the volume backup is crash-consistent.
8. **Then section 2** with the newest nightly backup of each environment, to bring back the days since the volume backup.

## 4. The VM is lost

1. A new VM: [Runbook 1](01-oci-account-and-vm.md). Reuse the existing `iltiam-data` volume if it survived, or restore it (section 3, steps 5 and 6).
2. The stack: [Runbook 5](05-compose-stack.md), sections 4 to 7 (the folders, the clone, the deploy key and address, a deploy of each environment through the `deploy` workflow). The deploy writes every env file, `backup.env` included, from GitHub.
3. The timers: [06-backups.md](06-backups.md), section 6.
4. The databases: section 2, if the volume was restored or is new.

**If GitHub's Environment secrets are lost too,** the age private keys are in Bitwarden (`age backup key staging`, `age backup key production`), and so are the other escrowed secrets ([Runbook 4](04-secrets.md), section 11). Set them again first ([06-backups.md](06-backups.md), section 8).

## 5. The timed rehearsal (acceptance: under 4 hours)

Issue #8 asks for a rehearsal that restores staging onto a fresh volume. **A fresh volume isn't possible on the free tier** (section 3: the 200 GB are in use). So the rehearsal runs section 2 for real on staging, which is the step every case ends with, and times it. Section 3's console steps are timed separately, on paper, from the OCI documentation's figures.

**When:** after the Dec 1 demo. Staging holds the demo data until then. Agree on a time in the team chat: staging is down for about 30 minutes.

1. Run the restore test first ([06-backups.md](06-backups.md), section 9). It must pass.
2. Write down the start time, then run section 2 with the newest nightly backup, timing each step:

   | Step | Started | Finished |
   |---|---|---|
   | 2.1 pick | | |
   | 2.2 fetch | | |
   | 2.3 stop | | |
   | 2.4 copy | | |
   | 2.5 restore | | |
   | 2.6 start and check | | |
   | 2.7 clean up | | |
   | **Total** (target under 4 h) | | |

3. Compare the row counts (`psql -c "SELECT count(*) …"` on a few tables you know) with the backup's `counts-iltiam.tsv`, before step 2.7 deletes it.
4. Copy the table into [06-backups.md](06-backups.md), section 14, row 11, and onto issue #8.
