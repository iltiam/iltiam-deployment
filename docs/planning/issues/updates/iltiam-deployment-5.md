# Local full-stack development environment (one command, seed, reset)

> **Plan ID:** DEP#5 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #23 in Thabit's list
> **Blocked by:** DEP#2
> **Blocks:** none

## Context

Re-scoped from "Demo laptop runbook". Every developer needs the whole system locally: same images as staging,
MinIO instead of OCI storage, fake SMS/email, the weight-free fake AI model available, ports that do not clash (the AI
and backend composes both publish 6379 and 8000 today).

## Steps

- [ ] `compose.dev.yml`: MinIO + init, mailpit, console SMS, optional `ILTIAM_SEG_MODEL=fake`.
- [ ] `scripts/dev-up.ps1` / `dev-reset.ps1` (migrate, `seed_demo --reset`, optional BE-09 series).
- [ ] Documented `--dart-define` values for the Android emulator / phone on the LAN; web dev proxy.
- [ ] `docs/dev-environment.md` replaces the scattered run steps (linked from each README).

## Acceptance criteria

- [ ] A clean clone + weights token reaches a working web and Android login in under 20 minutes.
- [ ] Reset under 1 minute.

## Tests required

- CI brings the dev stack up with the fake model and runs the API smoke.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
