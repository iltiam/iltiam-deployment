# Consented feedback dataset export for retraining (anonymised)

> **Plan ID:** BE-30 · **Owner:** Mansour (@Mn9p) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P2 · **Size:** S (≈1 day) · **Order:** #22 in Mansour's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** FR-D-7 (feedback dataset, consented), FR-P-7.1 (exclude after deletion)

## Context

Owned by Mansour (Omar reviews). Corrections from consenting patients feed future retraining; deleted/anonymised
patients must be excluded.

## Steps

- [ ] `manage.py export_feedback_dataset` (Super Admin) -> anonymised images, AI mask, corrected values/boundary, no identifiers.
- [ ] Excludes withdrawn consent and deletion requests.

## Acceptance criteria

- [ ] Export contains no identifiers (test scans for phone/name/ids).

## Tests required

- Command tests.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
