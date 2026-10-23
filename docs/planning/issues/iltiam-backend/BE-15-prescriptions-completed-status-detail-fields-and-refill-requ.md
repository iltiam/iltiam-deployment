# Prescriptions: COMPLETED status, detail fields and refill requests

> **Plan ID:** BE-15 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #25 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-22, MOB-32
> **SRS:** FR-P-5.1, FR-D-9

## Context

FR-P-5.1: statuses Active/Completed/Expired, detail (medication, dosage, frequency, duration, notes: model has them),
refill request button only for clinician-configured eligible prescriptions, expiry reminder 3 days before (exists).

## Steps

- [ ] Status COMPLETED (doctor marks, or end of duration).
- [ ] `refill_eligible` set by the doctor at upload; `POST /api/prescriptions/{id}/refill-requests/` (patient), doctor approve/reject, notifications both ways.
- [ ] OpenAPI + docs.

## Acceptance criteria

- [ ] Refill button data only for eligible prescriptions; full request lifecycle audited.

## Tests required

- API tests incl. RBAC.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
