# Backups and restores stay in Riyadh

- **Issue:** #6, step 5. **Recorded:** 2026-11-13.
- **The rule:** database dumps, volume backups and every restore or restore test stay on the **VM in Riyadh** and in the **Riyadh buckets**. They are **never** made, copied, restored or tested on GitHub Actions runners, a laptop, or any place outside OCI's Riyadh region.

## Why

- A dump is a full copy of the patients' health data: sensitive personal data that we keep in the Kingdom ([ADR-0004](../adr/0004-hosting.md)), and that ILTIAM treats as sensitive.
- GitHub's runners run outside the Kingdom, and this repository is public: its workflow logs and artifacts can be seen by anyone.

## What exists today

| What | Where | Made by | Restored by |
|---|---|---|---|
| **Pre-deploy dumps** of the staging backend database | the VM, `/srv/iltiam/backups/pre-deploy/` (folder 700, files 600, owner `deploy`); the newest 5 kept | `scripts/pre-deploy-backup.sh`, which the deploy workflow copies to the VM and **runs there**, over SSH ([Runbook 9](../runbooks/09-cd-staging.md), section 6) | by hand, on the VM ([Runbook 9](../runbooks/09-cd-staging.md), section 7) |
| **Scheduled backups** | `iltiam-<SHORT>-backups` (Riyadh, private, customer-managed key, [Runbook 8](../runbooks/08-object-storage.md)) | the backup job of #8 (Runbook 6), **not built yet** | the weekly restore test of #8, on the VM |

The GitHub workflow only starts the dump on the VM. It prints the file name and size, never the content, and the dump never travels to the runner.

## How the rule is kept

1. **Dumps are made on the VM** by a script running there. No workflow runs `pg_dump`, `pg_restore` or `psql` against a database on a runner.
2. **No dump in GitHub:** never `actions/upload-artifact`, a cache, a release asset, a commit or an issue attachment for a dump, a log excerpt with data, or a database file.
3. **Restore tests run on the VM** (or on another OCI VM in Riyadh), into a separate database or Compose project, and are removed afterwards. Never on a runner, never on a laptop.
4. **Copies stay in OCI Riyadh.** ADR-0004 mentions an optional copy in Jeddah, which is also in the Kingdom. If one is ever made, add it to the [ROPA](ropa.md) and to this page first.
5. **A dump leaves the VM only into `-backups`,** through the backup user of #8, which can write only there.

## Checks

| Check | How | Expected |
|---|---|---|
| No workflow touches a database | `grep -rnE 'pg_dump\|pg_restore\|psql\|upload-artifact' .github/workflows/` in this repository and the app repositories | no `pg_dump`, `pg_restore` or `psql` in any workflow; `upload-artifact` only for build outputs and test reports (checked 2026-11-13: the OpenAPI file, coverage, the web build, Playwright and Lighthouse reports, golden-test failures, the staging debug APK). The deploy workflow only runs `scripts/remote-deploy.sh` over SSH |
| The pre-deploy folder | on the VM: `sudo -u deploy ls -l /srv/iltiam/backups/pre-deploy/` | at most 5 `.sql.gz` files, mode `-rw-------`, owner `deploy` |
| Runbook 6 (#8) | review of its PR | it states this rule, and its restore test runs on the VM |

**Review:** with every change to a workflow, a backup script or Runbook 6, and before production (#36).
