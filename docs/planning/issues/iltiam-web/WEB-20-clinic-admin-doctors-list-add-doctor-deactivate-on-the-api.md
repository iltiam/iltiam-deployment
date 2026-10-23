# Clinic Admin: doctors list, add doctor, deactivate on the API

> **Plan ID:** WEB-20 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #9 in Mansour's list
> **Blocked by:** WEB-04
> **Blocks:** WEB-21, WEB-22
> **SRS:** FR-CA-2, FR-CA-3, FR-CA-6, UC-CA-01

## Context

Backend: `/api/clinic/doctors/` (GET/POST), `/api/clinic/doctors/{id}/status/`.

## Steps

- [ ] List with search/filter; add form (duplicate phone error, pending activation); deactivate with confirmation.

## Acceptance criteria

- [ ] Created doctor activates via WEB-05 flow.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
