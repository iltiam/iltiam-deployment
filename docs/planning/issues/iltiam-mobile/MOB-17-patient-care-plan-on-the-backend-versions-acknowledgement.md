# Patient care plan on the backend (versions, acknowledgement)

> **Plan ID:** MOB-17 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #21 in Mohammad's list
> **Blocked by:** MOB-04
> **Blocks:** none
> **SRS:** FR-P-5.2

## Context

Backend: `/api/care-plan/mine/`, `/api/care-plan/mine/versions/{id}/acknowledge/`.

## Steps

- [ ] Map current + history; acknowledgement with offline queue (existing).

## Acceptance criteria

- [ ] Doctor sees the acknowledgement on web.

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
