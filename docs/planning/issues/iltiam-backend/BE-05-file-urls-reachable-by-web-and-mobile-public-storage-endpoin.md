# File URLs reachable by web and mobile (public storage endpoint, absolute media URLs)

> **Plan ID:** BE-05 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #8 in Omar's list
> **Blocked by:** none
> **Blocks:** BE-06, BE-21
> **SRS:** FR-D-5, FR-P-3.1

## Context

Presigned URLs are signed for `STORAGE_ENDPOINT_URL` (internal) and local-disk URLs are root-relative `/media/...`,
so browsers on another origin and phones cannot load photos/masks.

## Steps

- [ ] Setting `STORAGE_PUBLIC_ENDPOINT_URL` used when signing GET URLs for clients.
- [ ] Absolute URLs for local-disk storage (dev) via `PUBLIC_BASE_URL`.
- [ ] Document in `.env.example` and `apps/storage/README.md`.

## Acceptance criteria

- [ ] On staging, photo/mask URLs from the API open in a browser and on a phone.

## Tests required

- Unit test of URL building for both storage modes.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
