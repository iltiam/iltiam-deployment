# Doctor: patient list (search, filters, risk colours) and register patient on the API

> **Plan ID:** WEB-06 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #1 in Mansour's list
> **Blocked by:** WEB-02
> **Blocks:** WEB-07
> **SRS:** FR-D-2, FR-D-3, NFR-PERF-02

## Context

Backend: `GET/POST /api/patients/` (search, risk_level, last_visit_after/before, pagination), duplicate phone error.

## Steps

- [ ] List page and register form on the API; keep current UI.
- [ ] Error envelope messages AR/EN.

## Acceptance criteria

- [ ] 50 patients load < 3 s on staging; duplicate phone shows "Phone number already exists".

## Tests required

- Component tests with MSW; Playwright in WEB-32.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
