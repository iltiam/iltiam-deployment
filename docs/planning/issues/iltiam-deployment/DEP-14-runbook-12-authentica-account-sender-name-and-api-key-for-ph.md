# Runbook 12: Authentica account, sender name and API key for phone codes

> **Plan ID:** DEP-14 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #11 in Thabit's list
> **Blocked by:** none
> **Blocks:** BE-20
> **SRS:** FR-SA-9, FR-D-1, FR-P-1.1, FR-P-1.3

## Context

Decision (ADR-0004, "Phone codes"): the backend keeps generating and checking its own codes and delivers them
through Authentica (Saudi provider: SMS, WhatsApp, email). This issue creates the account and credentials; the backend
code is BE-20. Write it as a runbook a teammate with no cloud experience can follow: numbered steps, exact console menu names, commands to paste, what you should see, and what to do if it fails. Never paste a secret into the runbook.

## Steps

- [ ] Create the Authentica account (authentica.sa) owned by ben-fatah; test with the 100 free credits, then buy the smallest package.
- [ ] Request an approved **sender name** (e.g. ILTIAM); record what Authentica needs for it and the lead time.
- [ ] API keys for staging and production -> GitHub Environment secrets `AUTHENTICA_API_KEY`, `AUTHENTICA_SENDER_NAME`.
- [ ] Monthly balance check (`GET /api/v2/balance`) as a monitoring probe or calendar reminder.
- [ ] Write `docs/runbooks/12-authentica.md`.

## Acceptance criteria

- [ ] A test SMS with our own text reaches a Saudi number from the approved sender name (or the interim path, BE-20, is recorded).

## Tests required

- Manual send recorded in the issue.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
