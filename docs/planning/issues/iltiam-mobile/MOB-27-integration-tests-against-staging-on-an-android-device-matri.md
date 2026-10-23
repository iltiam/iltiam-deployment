# Integration tests against staging on an Android device matrix

> **Plan ID:** MOB-27 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #27 in Mohammad's list
> **Blocked by:** MOB-08, MOB-16
> **Blocks:** MOB-28
> **Do after:** all other P0/P1 v1.0 issues in iltiam-mobile (release gate)
> **SRS:** SRS §5.5, NFR-POR-01

## Context

Prove the main journeys on real Android devices (Android 10 to latest) against staging test accounts. iOS devices: MOB-36.

## Steps

- [ ] `integration_test` journeys: patient capture->result, doctor review, messaging round-trip.
- [ ] Run on a small device matrix (physical + emulator; BrowserStack optional).

## Acceptance criteria

- [ ] Journeys green on Android 10 and the latest Android.

## Tests required

- The integration suite.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
