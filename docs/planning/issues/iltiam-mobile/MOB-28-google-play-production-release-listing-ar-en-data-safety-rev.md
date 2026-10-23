# Google Play production release: listing AR/EN, data safety, review, rollout

> **Plan ID:** MOB-28 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #28 in Mohammad's list
> **Blocked by:** MOB-28a, MOB-27, DEP#6
> **Blocks:** MOB-36, DEP-11
> **SRS:** NFR-POR-01

## Context

Production build of the prod flavor on Google Play: listing in Arabic and English, data-safety form matching the PDPL
mapping (deployment #6), app-access instructions with test accounts for reviewers, staged rollout. A personal Play
account needs the closed test from MOB-28a before production access. App Store is v1.1 (MOB-36).

## Steps

- [ ] Listing: name, short/long description AR/EN, screenshots (patient + doctor), icon, feature graphic, privacy policy `https://app.<DOMAIN>/privacy`, support email.
- [ ] Data safety, content rating, target audience, health-app declarations.
- [ ] Apply for production access (personal accounts), then staged rollout 20 % -> 100 %.

## Acceptance criteria

- [ ] Google Play approves v1.0 and it installs from the store.

## Tests required

- Release checklist.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
