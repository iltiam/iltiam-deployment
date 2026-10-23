# Model update without downtime (NFR-MAI-01)

> **Plan ID:** AI-05 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #25 in Thabit's list
> **Blocked by:** DEP-04
> **Blocks:** none
> **SRS:** NFR-MAI-01

## Context

Start new AI workers with the new weights, wait for readiness, then drain and stop the old ones; the api switches
when the new pipeline is loaded; the backend panel records the version change.

## Steps

- [ ] Graceful worker shutdown verified; visibility timeout covers redelivery.
- [ ] Deploy path for a weights-only change.
- [ ] Runbook + rehearsal with a dummy version bump.

## Acceptance criteria

- [ ] Model switch on staging with analyses running: zero failed jobs; new results carry the new version.

## Tests required

- verify_stack redeploy scenario.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
