# Google Play Console: app, Play App Signing, internal testing, and a 14-day closed test with 12 testers

> **Plan ID:** MOB-28a · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #6 in Mohammad's list
> **Blocked by:** MOB-03
> **Blocks:** MOB-28
> **SRS:** NFR-POR-01

## Context

Android ships on Google Play in v1.0. A **personal** developer account created after 13 Nov 2023 must run a closed test
with at least 12 testers opted in for 14 continuous days before it can apply for production access (Play Console Help,
"App testing requirements for new personal developer accounts"). An organisation account is exempt but needs a D-U-N-S
number. Start this early: any working build is enough, and later builds replace it during the 14 days.

## Steps

- [ ] The account owner creates the Play Console developer account (25 USD one-time) and invites Mohammad as admin.
- [ ] Create the app (prod flavor package id), enable Play App Signing, upload the first AAB signed with the upload key (MOB-03).
- [ ] Internal testing track for the team; closed testing track with >= 12 testers (team, friends, clinicians) opted in and kept opted in for 14 days.
- [ ] CI uploads each release-candidate AAB to the closed track (fastlane supply or the Play publishing API with a service-account secret).

## Acceptance criteria

- [ ] Closed test running with >= 12 opted-in testers; the date the 14 days end is written in this issue.

## Tests required

- CI upload job runs.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
