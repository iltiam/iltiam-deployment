# Clinic-scoped account event log for Clinic Admins

> **Plan ID:** BE-26 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #6 in Mansour's list
> **Blocked by:** none
> **Blocks:** WEB-22
> **SRS:** FR-CA-5, Table 15 (View Audit Logs, clinic scoped)

## Context

Owned by Mansour with WEB-22 (Omar reviews). `/api/audit-logs/` is Super Admin only; Clinic Admin needs a read-only
view of doctor creations, deactivations, updates and reassignments in their clinic, filterable by type/date.

## Steps

- [ ] `GET /api/clinic/audit-logs/` scoped to the admin's clinic and account-management categories.
- [ ] Filters type/date; pagination; RBAC matrix.

## Acceptance criteria

- [ ] Clinic Admin never sees another clinic's events or patient data.

## Tests required

- API + RBAC tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
