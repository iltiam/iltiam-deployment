# Health and readiness endpoints

> **Plan ID:** BE-02 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #5 in Omar's list
> **Blocked by:** none
> **Blocks:** DEP#2
> **SRS:** NFR-REL-01, NFR-AVA-01

## Context

No `/health` exists; compose healthchecks, the monitoring probe and the mobile reachability probe need one.

## Steps

- [ ] `GET /api/health/` (no auth, no DB) -> 200.
- [ ] `GET /api/ready/` (no auth): DB, Redis, storage, AI `/ready`; 503 with the failing dependency names, no secrets.
- [ ] Exclude both from throttling and audit middleware.

## Acceptance criteria

- [ ] `/api/ready/` returns 503 naming `ai` when the AI service is stopped.

## Tests required

- Unit tests for each failing dependency; RBAC matrix entry.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
