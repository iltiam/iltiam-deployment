# Super Admin: system dashboard (5-minute refresh, date range, PDF export)

> **Plan ID:** WEB-25 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #19 in Ahmed's list
> **Blocked by:** WEB-04
> **Blocks:** none
> **SRS:** FR-SA-7

## Context

Backend: `/api/stats/system/`, `/api/stats/system/export/`.

## Steps

- [ ] Tiles and charts from the API; auto-refresh 5 min; export.

## Acceptance criteria

- [ ] Numbers match backend; export downloads a PDF.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
