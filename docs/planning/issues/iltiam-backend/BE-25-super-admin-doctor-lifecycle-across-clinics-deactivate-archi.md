# Super Admin doctor lifecycle across clinics: deactivate, archive, soft delete

> **Plan ID:** BE-25 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #9 in Ahmed's list
> **Blocked by:** none
> **Blocks:** WEB-24
> **SRS:** FR-SA-6, FR-CA-6, Table 11, Table 15

## Context

Owned by Ahmed with WEB-24 (Omar reviews). Table 15: Archive Doctor and Soft Delete Doctor (logical) are Super Admin
only; Deactivate is SA and Clinic Admin. Today only the clinic-admin status endpoint exists and there is no
soft-deleted state (accounts.User.Status has ACTIVE/PENDING/INACTIVE/ARCHIVED).

## Steps

- [ ] `POST /api/clinics/{id}/doctors/{doctor_id}/status/` for Super Admin with deactivate/archive/soft_delete/reactivate.
- [ ] Soft delete = hidden from UI and search, kept for audit; patients stay assigned; login disabled.
- [ ] Clinic Admin limited to deactivate (Table 15); record the FR-CA-6 vs Table 15 inconsistency in docs.

## Acceptance criteria

- [ ] Read-only SA blocked; soft-deleted doctor hidden from lists but visible in audit.

## Tests required

- API + RBAC matrix tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
