# PDPL mapping, ROPA, retention schedule, consent texts and user agreement

> **Plan ID:** DEP#6 · **Owner:** Thabit (@ben-fatah) · **Reviewer:** repo owner (@ben-fatah)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** M (≈2 days) · **Order:** #18 in Thabit's list
> **Blocked by:** none
> **Blocks:** BE-22, MOB-28
> **SRS:** FR-P-7.1, NFR-SEC-04, FR-SA-10

## Context

Kept and updated for production. Drives the retention jobs (BE-22) and the consent/export/deletion features.
Lists every processor and what it receives: OCI (Riyadh, Jeddah), Cloudflare (TLS terminated at its edge; Saudi
Regional Services only with the paid Data Localization Suite), Authentica (phone number + code), Firebase/FCM (device
token + notification type, never health data), SMTP provider (email + code/links), uptime pinger (no data).

## Steps

- [ ] ROPA: data class, purpose, legal basis, location, processors.
- [ ] Retention schedule per data class with the enforcing job (images, analyses, notes, prescriptions, messages 12 months, audit >= 2 years, AI jobs 24 h).
- [ ] Consent texts (AR/EN) for AI analysis and the feedback dataset; privacy notice; terms of use; Play Store data-safety answers (MOB-28).
- [ ] Map each PDPL right (access, correction, export, withdrawal, deletion/anonymisation, breach notice 72 h) to feature, endpoint and test.
- [ ] Record: restore tests and production dumps stay on the Riyadh VM/buckets (never restored on GitHub runners).

## Acceptance criteria

- [ ] Every retention row names a job or a documented manual process.
- [ ] Web and Android show these texts (WEB-05, MOB-25).

## Tests required

- Team review; links to the backend tests proving each right.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
