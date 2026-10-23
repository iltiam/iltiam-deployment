# Structured patient notes on upload (pain level, odour, discharge colour)

> **Plan ID:** BE-42 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** S (≈1 day) · **Order:** #23 in Mansour's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** FR-P-2.2 (optional patient notes)

## Context

Owned by Mansour (Omar reviews; mobile MOB-04 sends them). FR-P-2.2 lists pain level, odour and discharge colour; the
upload takes free-text `notes` only.

## Steps

- [ ] Optional fields `pain_level` (0-10), `odour` (enum), `discharge_colour` (enum) on patient upload; shown to the doctor.

## Acceptance criteria

- [ ] Fields validated and visible in VisitDetail.

## Tests required

- Serializer tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
