# Super Admin: clinics directory, provisioning and lifecycle (activate/deactivate/archive)

> **Plan ID:** WEB-23 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #12 in Ahmed's list
> **Blocked by:** WEB-04
> **Blocks:** WEB-32
> **SRS:** FR-SA-4, FR-SA-5, UC-SA-01, UC-SA-02

## Context

Backend: `/api/clinics/` (GET/POST), `/{id}/`, `/{id}/status/` (reason, archive policy), `/{id}/resend-activation/`.

## Steps

- [ ] Directory, provision form (unique name), lifecycle actions with reason and archive policy, resend activation.

## Acceptance criteria

- [ ] Deactivating a clinic logs its doctors out (backend) and UI shows read-only state.

## Tests required

- Component tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
