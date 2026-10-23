# Cross-browser verification (latest two Chrome, Firefox, Safari)

> **Plan ID:** WEB-34 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Mn9p / @aalbabtain)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #21 in Mansour's list
> **Blocked by:** WEB-32
> **Blocks:** none
> **SRS:** NFR-POR-02

## Context

Run the Playwright suite on Chromium, Firefox and WebKit; fix differences.

## Steps

- [ ] Add browsers to the staging project; triage failures.

## Acceptance criteria

- [ ] Suite green on all three engines.

## Tests required

- The suite.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
