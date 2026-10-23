# Security fixes from scans and review (ZAP, dependency audit)

> **Plan ID:** BE-24 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #16 in Mansour's list
> **Blocked by:** DEP-07
> **Blocks:** none
> **SRS:** NFR-SEC

## Context

Owned by Mansour (Omar reviews): resolve High/Medium findings from DEP-07 for the backend.

## Steps

- [ ] Triage and fix findings; document accepted risks.

## Acceptance criteria

- [ ] No open High findings.

## Tests required

- Regression tests per fix.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
