# System-level SRS divergence register (decisions that differ from the SRS PDF)

> **Plan ID:** DEP-12 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P1 · **Size:** S (≈1 day) · **Order:** #27 in Omar's list
> **Blocked by:** none
> **Blocks:** none
> **SRS:** SRS §6.1 Table 8, FR-P-1.1, FR-CA-6, Table 15, §17

## Context

Owned by Omar; ben-fatah reviews. iltiam-ai-service keeps `docs/srs/divergences.md` for the AI only. Product decisions
that differ from the SRS PDF must be recorded once: doctor mobile app (Table 8 gives doctors the web only); patient
login keeps phone + password + code (FR-P-1.1 wording); "wound not found" asks for a retake and says the doctor will
review; per-request threshold for FR-D-5 governance; Table 15 vs FR-CA-6 (Clinic Admin archive/soft delete);
Cloudflare Tunnel instead of NGINX (§17); Authentica instead of Twilio (§17); hosting per ADR-0004; iOS release
moved to v1.1.

## Steps

- [ ] `docs/srs-divergences.md` in iltiam-deployment: SRS says / we do / why / decided by / date / SRS section to update.
- [ ] Link it from every repo README and from the AI divergences file.

## Acceptance criteria

- [ ] Every decision above has a row; owners agree in review.

## Tests required

- Doc review.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
