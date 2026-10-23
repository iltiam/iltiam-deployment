# Doctor: patient profile with wounds and image timeline

> **Plan ID:** WEB-07 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #5 in Mansour's list
> **Blocked by:** WEB-06, BE-07
> **Blocks:** WEB-15, WEB-16, WEB-18, WEB-17
> **SRS:** FR-D-3, FR-D-6

## Context

Backend: `GET /api/patients/{id}/`, `/wounds/`, `GET /api/wounds/{id}/visits/` (BE-07).

## Steps

- [ ] Profile header, wounds tabs, visits timeline with thumbnails and statuses, quick actions (upload, note, prescribe).

## Acceptance criteria

- [ ] Profile shows every submission including retakes and failures.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
