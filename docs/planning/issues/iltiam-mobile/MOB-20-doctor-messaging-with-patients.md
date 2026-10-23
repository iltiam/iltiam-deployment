# Doctor: messaging with patients

> **Plan ID:** MOB-20 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #20 in Ahmed's list
> **Blocked by:** MOB-04
> **Blocks:** none
> **SRS:** FR-D-13

## Context

Built by Ahmed in Flutter (he owns the same feature on the web); Mohammad reviews. Backend: `/api/messages/conversations/`, `/{patient_id}/` (GET/POST), `/{patient_id}/read/`, `/api/messages/availability/`.

## Steps

- [ ] Map inbox, thread, send (with visit attachment), read receipts, availability toggle.

## Acceptance criteria

- [ ] Round-trip with the patient app.

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
