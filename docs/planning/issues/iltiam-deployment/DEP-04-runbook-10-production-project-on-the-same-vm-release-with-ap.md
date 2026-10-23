# Runbook 10: production project on the same VM, release with approval, rollback, and when to split

> **Plan ID:** DEP-04 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #20 in Thabit's list
> **Blocked by:** DEP-03, DEP#8, DEP-02
> **Blocks:** AI-05, DEP-11
> **SRS:** NFR-MAI-01, NFR-AVA-01

## Context

Free-first (ADR-0004): Oracle **Always Free** in the Riyadh home region: one Ampere A1 (ARM, aarch64) VM with **2 OCPUs and 12 GB** (Oracle's current Always Free A1 allowance), 200 GB block storage in total, 20 GB object storage, software-protected Vault keys. Staging and production share this one VM as separate Compose projects. Production is the `iltiam-prod` Compose project on `iltiam-1` with its own databases, buckets, tunnel
(`app.<DOMAIN>`, `api.<DOMAIN>`) and secrets. Releases are semver tags collected in a release manifest; deploying needs
an approver. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] GitHub Environment `production` (required reviewers); `release.yml` deploys a manifest to `iltiam-prod` with a rolling restart (start new backend web, wait healthy, stop old; graceful worker drain) and a read-only smoke.
- [ ] `rollback.yml`: redeploy the previous manifest.
- [ ] **Split triggers** (move production to its own VM; paid, see ADR-0004 cost table): memory > 85 % for a week, production upload->result p95 > 4 s caused by staging load, a clinic contract requiring isolation, or object storage beyond the free 20 GB being the cheaper half of the bill.
- [ ] Write `docs/runbooks/10-production-release.md` (release checklist, rollback criteria, split procedure).

## Acceptance criteria

- [ ] Release and rollback rehearsed on the VM with zero failed requests during the switch.
- [ ] Production deploy requires an approver.

## Tests required

- Rehearsal log in the issue.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
