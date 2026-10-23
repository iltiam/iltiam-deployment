# Playwright E2E suite against staging (all actors)

> **Plan ID:** WEB-32 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #20 in Mansour's list
> **Blocked by:** WEB-10, WEB-23
> **Blocks:** WEB-34, DEP-11
> **Do after:** all other P0/P1 v1.0 issues in iltiam-web (E2E suite covers the finished pages)
> **SRS:** SRS §5.5, §5.7, Test cases A-L

## Context

The smoke test asserts mock data (`v2.4.0`, "Jamal Abdullah"). Replace with journeys on staging test accounts.

## Steps

- [ ] Projects: `mock` (CI unit-level, MSW) and `staging` (real).
- [ ] Journeys: doctor upload->result->review; alert acknowledge; clinic admin add doctor + reassign; SA clinic lifecycle + audit; threshold change (when ready).

## Acceptance criteria

- [ ] Staging suite green and runnable from deployment smoke (DEP-10).

## Tests required

- The suite.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
