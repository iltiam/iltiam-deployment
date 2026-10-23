# Production image (linux/arm64) and weights delivery for staging and production

> **Plan ID:** AI-07 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #6 in Thabit's list
> **Blocked by:** DEP#1, AI-12
> **Blocks:** AI-04, DEP#2
> **SRS:** NFR-MAI-01, NFR-MAI-04

## Context

Weights are in a private GitHub release and excluded from the image (#119). Both environments on the one VM share one
read-only weights volume. The image must run on ARM: torch/torchvision from the CPU index have aarch64 wheels; opencv,
numpy, pillow, psycopg, transformers' native deps (tokenizers, safetensors) too (checked 2026-10-23).

## Steps

- [ ] Adopt `docker-publish.yml` for the `api` and `worker` targets with `platforms: linux/arm64,linux/amd64`.
- [ ] One-shot `weights-init` container fills `/srv/iltiam/weights` (read-only mount for both environments) with `scripts/download_weights.py` and a read-only token; refuse to start on checksum mismatch.
- [ ] Make gunicorn workers configurable (`AI_API_WORKERS`, default 2) so the shared VM can run 1 per environment; each worker loads its own pipeline (~1.2 GB).

## Acceptance criteria

- [ ] Staging AI is healthy on the A1 VM from a GHCR arm64 image with verified weights.
- [ ] Wrong checksum -> `/ready` 503 with a clear reason.

## Tests required

- CI builds both architectures; integration test of the init script with a fake release.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
