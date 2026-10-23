# Clinic Admin: reassign patients (single, bulk, unassigned)

> **Plan ID:** WEB-21 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #10 in Mansour's list
> **Blocked by:** WEB-20
> **Blocks:** none
> **SRS:** FR-CA-7, UC-CA-02

## Context

Backend: `/api/clinic/patients/`, `/api/clinic/patients/reassign/`.

## Steps

- [ ] Reassign modal for single and bulk; "Unassigned" option with warning when no active doctor.

## Acceptance criteria

- [ ] Audit entry per patient (backend); UI reflects new assignments.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
