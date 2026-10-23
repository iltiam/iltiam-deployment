# Doctor (mobile): care plan editor and appointment requests (confirm/reject/reschedule)

> **Plan ID:** MOB-33 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** M (≈2 days) · **Order:** #30 in Ahmed's list
> **Blocked by:** MOB-12
> **Blocks:** none
> **SRS:** FR-P-5.2 (clinician side), FR-P-4.1 (clinician side)

## Context

Built by Ahmed in Flutter (he owns the same feature on the web); Mohammad reviews. Backend: `/api/patients/{id}/care-plan/`, `/api/appointments/{id}/confirm|reject|reschedule|complete/`.

## Steps

- [ ] Care plan editor (AR/EN), shared notes control; appointment request handling.

## Acceptance criteria

- [ ] Patient sees the published plan and the appointment status change.

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
