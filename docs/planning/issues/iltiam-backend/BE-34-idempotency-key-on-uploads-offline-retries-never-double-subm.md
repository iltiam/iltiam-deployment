# Idempotency-Key on uploads (offline retries never double-submit)

> **Plan ID:** BE-34 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #28 in Omar's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** FR-P-2.2, FR-P-7.2, NFR-REL-02

## Context

Mobile retries queued uploads with the same `Idempotency-Key`; the backend ignores it, so a retry after a lost response
creates a second visit (or a 409 duplicate prompt).

## Steps

- [ ] Store key+user+hash for 24 h; same key returns the original 201 response.

## Acceptance criteria

- [ ] Two identical requests with one key create one visit.

## Tests required

- API test with replay.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
