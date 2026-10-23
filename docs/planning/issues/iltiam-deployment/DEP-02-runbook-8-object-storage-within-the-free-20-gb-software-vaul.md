# Runbook 8: object storage within the free 20 GB, software Vault keys, S3 credentials

> **Plan ID:** DEP-02 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #9 in Thabit's list
> **Blocked by:** DEP#7
> **Blocks:** BE-21, DEP#8, DEP-04
> **SRS:** NFR-SEC-04 (AES-256, KMS-managed, yearly rotation); SRS §17 (Object Storage)

## Context

Free-first (ADR-0004): Oracle **Always Free** in the Riyadh home region: one Ampere A1 (ARM, aarch64) VM with **2 OCPUs and 12 GB** (Oracle's current Always Free A1 allowance), 200 GB block storage in total, 20 GB object storage, software-protected Vault keys. Staging and production share this one VM as separate Compose projects. Object Storage Always Free: 20 GB (a free-only account: combined tiers; a Pay-As-You-Go account: 10 GB Standard + 10 GB
Infrequent Access + 10 GB Archive) and 50,000 API requests/month. Vault: **software-protected master keys are free**
(HSM keys: 20 key versions free), still AES-256 and rotatable, which meets NFR-SEC-04. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] Vault `iltiam` -> master encryption key, protection mode **Software** (free); document yearly rotation.
- [ ] Buckets per environment and data class (`iltiam-<env>-wound-images`, `-masks`, `-prescriptions`, `-exports`, `-backups`), Private, customer-managed key, versioning off for images (saves space), on for prescriptions.
- [ ] Lifecycle: exports deleted after 7 days; backups move to Infrequent Access.
- [ ] IAM user for the backend limited to its buckets; Customer Secret Keys -> S3 keys -> GitHub Environment secrets; endpoint `https://<namespace>.compat.objectstorage.me-riyadh-1.oraclecloud.com`, region `me-riyadh-1`, path-style (BE-21).
- [ ] Capacity: 10 GB of photos is about 3,000-5,000 analyses at 2-3 MB; alert at 70 % of the free storage (DEP#10); beyond it costs about $0.0255/GB-month.
- [ ] Write `docs/runbooks/08-object-storage.md`.

## Acceptance criteria

- [ ] `manage.py check_storage` passes against OCI for both environments.
- [ ] Objects show "customer-managed key"; billing shows $0.

## Tests required

- `check_storage` in the post-deploy smoke.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
