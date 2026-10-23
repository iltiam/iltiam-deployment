# Doctor: SOAP clinical notes on the API

> **Plan ID:** WEB-15 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #11 in Mansour's list
> **Blocked by:** WEB-07
> **Blocks:** none
> **SRS:** FR-D-8

## Context

Backend: `/api/patients/{id}/notes/`, `/api/notes/{id}/` (PATCH draft autosave, sign, addenda, share).

## Steps

- [ ] Editor with structured fields and tags; draft autosave; sign; addendum; share toggle.

## Acceptance criteria

- [ ] Signed notes are immutable; shared notes visible to the patient app.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
