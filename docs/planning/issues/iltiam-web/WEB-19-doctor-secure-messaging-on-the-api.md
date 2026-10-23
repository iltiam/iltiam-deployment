# Doctor: secure messaging on the API

> **Plan ID:** WEB-19 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #17 in Ahmed's list
> **Blocked by:** WEB-04
> **Blocks:** none
> **SRS:** FR-D-13

## Context

Backend: `/api/messages/conversations/`, `/{patient_id}/` (GET/POST, attachment visit id), `/read/`, `/availability/`.

## Steps

- [ ] Inbox, thread, send with attachment picker from submission history, read receipts, availability (auto-reply).

## Acceptance criteria

- [ ] Round-trip with the patient app on staging.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
