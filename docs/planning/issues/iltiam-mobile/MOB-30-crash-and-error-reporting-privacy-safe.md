# Crash and error reporting (privacy-safe)

> **Plan ID:** MOB-30 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** S (≈1 day) · **Order:** #29 in Mohammad's list
> **Blocked by:** MOB-02
> **Blocks:** none
> **SRS:** NFR-REL-01

## Context

Crash reporting without health data (Crashlytics or self-hosted GlitchTip per ADR-0004).

## Steps

- [ ] Integrate, scrub PII, opt-in per policy.

## Acceptance criteria

- [ ] Test crash appears with no personal data.

## Tests required

- Manual.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
