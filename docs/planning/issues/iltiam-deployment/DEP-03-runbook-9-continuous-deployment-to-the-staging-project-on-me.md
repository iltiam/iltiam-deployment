# Runbook 9: continuous deployment to the staging project on merge to main

> **Plan ID:** DEP-03 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #16 in Thabit's list
> **Blocked by:** DEP#1, DEP#2
> **Blocks:** DEP-07, DEP-10, DEP-04, DEP-08

## Context

When an app repo publishes an arm64 image from `main`, the `iltiam-staging` project on `iltiam-1` updates that service
and runs the smoke (DEP-10). Production on the same VM is untouched. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] Each repo's publish job sends `repository_dispatch` to `deploy-staging.yml`.
- [ ] Job: SSH as `deploy` (key in secrets), write staging env files, update `env/staging.versions`, `scripts/deploy.sh staging`, smoke, comment the result; concurrency group; automatic rollback on a failed smoke.
- [ ] Guard: the job may only touch the `iltiam-staging` project (the script refuses other project names).
- [ ] Write `docs/runbooks/09-cd-staging.md`.

## Acceptance criteria

- [ ] A merge to backend `main` is live on staging within 15 minutes; production containers are not restarted.
- [ ] A failing smoke rolls back.

## Tests required

- Dummy change per repo; check production uptime during staging deploys.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
