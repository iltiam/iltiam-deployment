# iOS builds: signing, flavors and TestFlight

> **Plan ID:** MOB-34 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.1 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #30 in Mohammad's list
> **Blocked by:** MOB-02
> **Blocks:** MOB-35, MOB-36
> **SRS:** NFR-POR-01 (iOS 14+)

## Context

v1.1. Apple Developer Program enrolment, certificates and profiles, schemes per flavor, CI builds uploaded to TestFlight.

## Steps

- [ ] Enrol (owner decides personal or organisation); App Store Connect app record.
- [ ] Signing via fastlane match (private repo) or an App Store Connect API key in CI secrets.
- [ ] CI builds the staging IPA and uploads it to TestFlight internal testing.

## Acceptance criteria

- [ ] Every merge to main produces a TestFlight build.

## Tests required

- CI workflow.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
