# Doctor: appointments and next-visit reminders on the API

> **Plan ID:** WEB-18 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #12 in Mansour's list
> **Blocked by:** WEB-07
> **Blocks:** none
> **SRS:** FR-D-10, FR-P-4.1

## Context

Backend: `/api/appointments/` (confirm, reject, reschedule, complete), `/api/patients/{id}/next-visit/`.

## Steps

- [ ] Requests list and actions; next-visit form (one pending per patient).

## Acceptance criteria

- [ ] Patient mobile request appears and confirmation notifies the patient.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
