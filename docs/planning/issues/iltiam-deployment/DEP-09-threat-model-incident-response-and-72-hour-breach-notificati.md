# Threat model, incident response and 72-hour breach notification runbook

> **Plan ID:** DEP-09 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** M (≈2 days) · **Order:** #24 in Thabit's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** FR-P-7.1 (breach within 72 h), NFR-SEC, NFR-MAI-02

## Context

Complements DEP#6: STRIDE model of the deployed system, incident response plan, and the breach procedure BE-17 supports.

## Steps

- [ ] STRIDE per container and data flow; mitigations mapped to issues.
- [ ] Incident response: roles, severities, contacts, evidence (audit log, Loki).
- [ ] Breach runbook: assess, decide, notify SDAIA and patients within 72 h with BE-17, record.

## Acceptance criteria

- [ ] One tabletop exercise run; findings filed.

## Tests required

- Tabletop notes attached.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
