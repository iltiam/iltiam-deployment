# Patient profile and preferences (medical background, photo, language, notification preferences)

> **Plan ID:** MOB-23 · **Owner:** Mohammad (@MYF25) · **Reviewer:** repo owner (@MYF25)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #25 in Mohammad's list
> **Blocked by:** MOB-04
> **Blocks:** none
> **SRS:** FR-P-1.2, FR-P-3.2

## Context

Backend: `/api/patients/me/` (GET/PATCH), `/api/patients/me/photo/` (POST/DELETE), `/api/notifications/preferences/`.

## Steps

- [ ] Map profile edit, photo, language (persists and sent as Accept-Language), per-type notification preferences and submission reminder frequency.

## Acceptance criteria

- [ ] Preference changes affect which pushes arrive.

## Tests required

- Repository tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
