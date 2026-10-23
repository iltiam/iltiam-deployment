# Patient privacy on the backend: consents, export jobs, access log, deletion request and cancel, step-up

> **Plan ID:** MOB-25 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #22 in Mohammad's list
> **Blocked by:** BE-12, BE-13, BE-14
> **Blocks:** none
> **SRS:** FR-P-7.1

## Context

Mobile calls `/patients/me/exports...`, `/auth/step-up/...`, `/deletion-requests...` which arrive with BE-12/13/14.

## Steps

- [ ] Map consents (`/api/patients/me/consents/` PATCH), exports jobs, access log, deletion request + cancel, step-up before each sensitive action.

## Acceptance criteria

- [ ] Export downloads; consent withdrawal stops new analyses (backend CONSENT_WITHDRAWN).

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
