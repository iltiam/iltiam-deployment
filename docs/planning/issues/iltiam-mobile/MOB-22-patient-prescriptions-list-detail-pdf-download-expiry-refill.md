# Patient prescriptions: list, detail, PDF download, expiry, refill request

> **Plan ID:** MOB-22 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #24 in Mohammad's list
> **Blocked by:** MOB-04, BE-15
> **Blocks:** none
> **SRS:** FR-P-5.1, UC-PT-03

## Context

Backend: `/api/prescriptions/mine/`, `/api/prescriptions/{id}/`, `/download/` (presigned), refill requests (BE-15).

## Steps

- [ ] Active/Completed/Expired lists, detail fields, download and open PDF, refill button only when eligible.

## Acceptance criteria

- [ ] PDF uploaded on web downloads on the phone.

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
