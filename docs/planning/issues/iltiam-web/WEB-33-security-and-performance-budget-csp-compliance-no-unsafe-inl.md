# Security and performance budget: CSP compliance, no unsafe-inline, bundle budget, error monitoring

> **Plan ID:** WEB-33 · **Owner:** Ahmed (@aalbabtain) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #14 in Ahmed's list
> **Blocked by:** WEB-03
> **Blocks:** none
> **SRS:** NFR-PERF-02, NFR-SEC, NFR-POR-02

## Context

Hardening of the SPA itself.

## Steps

- [ ] Remove inline scripts/styles that break CSP; tokens: access in memory, refresh in sessionStorage (keep).
- [ ] Bundle budget (route-level code splitting) so first load < 3 s on staging.
- [ ] Error monitoring (GlitchTip/Sentry per ADR) with PII scrubbing.

## Acceptance criteria

- [ ] Lighthouse performance >= 90 on dashboard on staging; CSP report-only shows no violations.

## Tests required

- Lighthouse CI step.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
