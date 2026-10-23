# Dev/staging command: seed a real dated analysis series through the AI pipeline

> **Plan ID:** BE-09 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #15 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-10, WEB-12
> **SRS:** FR-D-6, UC-DR-03; decision (owner): dev/staging only

## Context

A series is dated by `captured_at` (auto_now_add, apps/wounds/models.py:256), so uploads on one day give
INSUFFICIENT_DATA. `seed_demo` uses a synthetic stand-in. Production keeps real capture dates.

## Steps

- [ ] `manage.py seed_ai_series --patient --location --images a b c --days-ago 28 14 3`, refused unless `ENVIRONMENT in (dev, staging)`.
- [ ] Creates visits/assessments with backdated timestamps and runs each through the real AI pipeline in order, then progression and alerts.
- [ ] Use the printed-wound field set (AI-09) when available.

## Acceptance criteria

- [ ] Wound shows 3 points with a real progression@1.3.0 trend and risk@1.1.0.

## Tests required

- Command test with the fake AI client; refusal test in production settings.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
