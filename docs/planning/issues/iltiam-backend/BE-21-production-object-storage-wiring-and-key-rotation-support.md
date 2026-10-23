# Production object storage wiring and key rotation support

> **Plan ID:** BE-21 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #22 in Omar's list
> **Blocked by:** DEP-02, BE-05
> **Blocks:** none
> **SRS:** NFR-SEC-04

## Context

Point storage at the provider buckets from DEP-02; keep MinIO for dev. Make sure SSE is enforced and presign expiry
is <= 15 min everywhere.

## Steps

- [ ] Settings for endpoint/region/addressing style; `check_storage` covers provider SSE.
- [ ] Doc: what changes when the KMS key rotates (nothing for the app).

## Acceptance criteria

- [ ] Staging runs on provider storage; check_storage green.

## Tests required

- check_storage unit tests with moto/minio.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
