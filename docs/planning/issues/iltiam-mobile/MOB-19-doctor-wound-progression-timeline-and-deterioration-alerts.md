# Doctor: wound progression timeline and deterioration alerts

> **Plan ID:** MOB-19 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #17 in Mohammad's list
> **Blocked by:** MOB-12
> **Blocks:** none
> **SRS:** FR-D-6, FR-D-11, UC-DR-03

## Context

Backend: `GET /api/wounds/{id}/progression/` (per wound), `GET /api/alerts/`, `POST /api/alerts/{id}/acknowledge/`
(justification). Alerts have no read/read-all endpoints; use notifications for read state.

## Steps

- [ ] Timeline with images (BE-07), area chart, healing rate, colour status, date filter.
- [ ] Alerts list with acknowledge.

## Acceptance criteria

- [ ] Seeded deteriorating patient shows red with active alerts; acknowledging removes them.

## Tests required

- Repository + widget tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
