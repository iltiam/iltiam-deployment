# Go-live checklist and production launch

> **Plan ID:** DEP-11 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #26 in Thabit's list
> **Blocked by:** DEP-04, DEP-08, MOB-28, WEB-32
> **Blocks:** none
> **Do after:** every other P0/P1 v1.0 issue in all repos (go-live gate)

## Context

Final gate before real users.

## Steps

- [ ] Checklist: backups and restore test green, alerts tested, production secrets differ from staging, first Super Admin bootstrapped (BE-31), dev flags off, Play production approved, status page live, **$10 budget alert active and billing at $0**, memory headroom on the VM.
- [ ] Rollback criteria and a 48 h watch rota.

## Acceptance criteria

- [ ] Checklist signed in the issue; production serving real logins.

## Tests required

- Read-only production smoke.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
