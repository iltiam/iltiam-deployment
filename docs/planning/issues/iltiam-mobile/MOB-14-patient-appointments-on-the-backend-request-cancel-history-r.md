# Patient appointments on the backend (request, cancel, history, reminders)

> **Plan ID:** MOB-14 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #20 in Mohammad's list
> **Blocked by:** MOB-04
> **Blocks:** none
> **SRS:** FR-P-4.1, UC-PT-03

## Context

Appointments live only in a local encrypted store. Backend: `/api/appointments/mine/` (GET/POST),
`/api/appointments/{id}/cancel/`; max 3 active; cancel >= 2 h before.

## Steps

- [ ] Dio repository behind CachingAppointmentRepository (offline read).
- [ ] Map statuses and backend error codes.

## Acceptance criteria

- [ ] Requests appear in the doctor web appointments list.

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
