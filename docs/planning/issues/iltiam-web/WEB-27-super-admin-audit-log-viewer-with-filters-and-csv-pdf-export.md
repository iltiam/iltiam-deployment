# Super Admin: audit log viewer with filters and CSV/PDF export

> **Plan ID:** WEB-27 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #21 in Ahmed's list
> **Blocked by:** WEB-04
> **Blocks:** none
> **SRS:** FR-SA-10, NFR-MAI-02

## Context

Backend: `/api/audit-logs/` (filters date, clinic, event type, actor), `/export/`.

## Steps

- [ ] Paginated viewer, filters, exports.

## Acceptance criteria

- [ ] Read-only SA can view and export.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
