# Cross-repo end-to-end smoke after every staging deploy

> **Plan ID:** DEP-10 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #8 in Mansour's list
> **Blocked by:** DEP-03
> **Blocks:** none
> **SRS:** SRS §5.7 (regression on every merge)

## Context

Owned by Mansour; ben-fatah reviews. A short API journey proves the integration after each deploy: log in as a staging
test doctor (BE-31), create a patient, upload a fixture photo, poll to COMPLETED, read progression; plus health,
cache-status and security-header checks.

## Steps

- [ ] `smoke/` package (Python or Playwright API mode).
- [ ] Staging test accounts and fixture photos (AI-09 printed-wound set once released).
- [ ] Runs from DEP-03 after each deploy; summary on the commit.

## Acceptance criteria

- [ ] Smoke finishes in < 3 minutes and fails the deploy on any broken step.

## Tests required

- The smoke itself; a broken-deploy rehearsal.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
