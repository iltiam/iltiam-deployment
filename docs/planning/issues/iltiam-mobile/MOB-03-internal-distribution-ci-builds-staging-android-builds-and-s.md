# Internal distribution: CI builds staging Android builds and ships them to testers

> **Plan ID:** MOB-03 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #3 in Mohammad's list
> **Blocked by:** MOB-02
> **Blocks:** MOB-28a
> **SRS:** NFR-POR-01, SRS §5.8 (physical devices)

## Context

The team needs installable Android staging builds after every merge for end-to-end checks. iOS builds are v1.1 (MOB-34). Adopts the reusable flutter CI (deployment #1).

## Steps

- [ ] Android upload keystore created once and stored as CI secrets (keystore base64, passwords); never committed.
- [ ] Workflow on `main`: build the staging AAB/APK with `google-services.json` from secrets; upload to Firebase App Distribution for the team.
- [ ] Version code from the build number; version name from the tag.

## Acceptance criteria

- [ ] Every merge to main produces an installable staging Android build within 30 minutes.

## Tests required

- CI workflow runs.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
