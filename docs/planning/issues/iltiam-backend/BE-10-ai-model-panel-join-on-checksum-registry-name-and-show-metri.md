# AI model panel: join on checksum/registry_name and show metrics, threshold, tissue status

> **Plan ID:** BE-10 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #26 in Omar's list
> **Blocked by:** AI-01, BE-32
> **Blocks:** WEB-26
> **SRS:** FR-SA-8, UC-SA-03

## Context

`model_panel._registry_entry` (apps/integrations/ai/model_panel.py:92-98) matches by name+version, which never matches
the real `/capabilities`, so Dice/IoU/date are always null.

## Steps

- [ ] Join `models.segmentation.checksum == registry[].sha256`, fallback `registry_name`.
- [ ] Add `decision_rules` and the active threshold (BE-11a) to the panel; tissue shown per #56.

## Acceptance criteria

- [ ] Against a real capture the panel shows Dice 0.8896, IoU 0.8177, released_at, threshold.

## Tests required

- Panel tests with the real fixture.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
