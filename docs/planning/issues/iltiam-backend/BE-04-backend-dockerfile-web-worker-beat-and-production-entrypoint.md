# Backend Dockerfile (web, worker, beat) and production entrypoint

> **Plan ID:** BE-04 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #6 in Omar's list
> **Blocked by:** DEP#1
> **Blocks:** BE-03, DEP#2
> **SRS:** SRS §17 (Application Server)

## Context

Deployment compose (iltiam-deployment#2) needs a backend image; the repo has none (issue-25 notes it). Python 3.13
slim, gunicorn, non-root, one image with three commands.

## Steps

- [ ] Multi-stage Dockerfile; `.dockerignore`; non-root user; collectstatic at build.
- [ ] Commands: `web` (gunicorn, workers from env), `worker` (`-Q wound.image.queued,notifications`), `beat` (single), `migrate` (one-shot job).
- [ ] HEALTHCHECK on `/api/health/` (BE-02); graceful shutdown for workers.
- [ ] Publish via the reusable `docker-publish.yml` (deployment #1).
- [ ] Build for `linux/arm64` and `linux/amd64` (the server is ARM, ADR-0004); all Python deps have aarch64 wheels (psycopg2-binary, cryptography, uharfbuzz, grpcio checked 2026-10-23).

## Acceptance criteria

- [ ] Image builds in CI and runs against compose Postgres/Redis/MinIO; all three roles healthy.
- [ ] `docker manifest inspect` shows an arm64 image; it runs on the A1 VM.

## Tests required

- CI: build + container smoke (migrate, health).

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
