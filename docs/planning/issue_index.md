# Issue index (all plan items, by owner and order)

| Owner | # | Plan ID | Repo | Title | Priority | Size | Milestone | Blocked by | Blocks | Action |
|---|---|---|---|---|---|---|---|---|---|---|
| Thabit | 1 | DEP#7 | deployment | Runbook 1: Oracle Always Free account (Riyadh), $10 budget alert, one Ampere A1 VM with Docker | P0 | M | v1.0 | — | AI-12, DEP#2, DEP#9, DEP-02 | update #7 |
| Thabit | 2 | AI-12 | ai-service | ARM go/no-go: measure the analysis latency on the Ampere A1 VM against the 4 s budget | P0 | S | v1.0 | DEP#7 | AI-07, DEP#2 | new |
| Thabit | 3 | DEP#1 | deployment | Reusable GitHub Actions workflows (python-ci, node-ci, flutter-ci, multi-arch docker build+push to GHCR) | P0 | M | v1.0 | — | DEP-07, BE-04, WEB-03, AI-07, DEP-03 | update #1 |
| Thabit | 4 | DEP#3 | deployment | Runbook 4: secrets and environment files (GitHub Environments, rotation, third-party keys) | P0 | M | v1.0 | — | BE-19, BE-20, DEP#2, DEP#9 | update #3 |
| Thabit | 5 | DEP-01 | deployment | Runbook 2: Cloudflare account, DNS for <DOMAIN>, SSL/TLS and email records | P0 | S | v1.0 | — | BE-20, DEP#9 | new |
| Thabit | 6 | AI-07 | ai-service | Production image (linux/arm64) and weights delivery for staging and production | P0 | M | v1.0 | DEP#1, AI-12 | AI-04, DEP#2 | new |
| Thabit | 7 | AI-10 | ai-service | Contract release process: versioned schemas/OpenAPI artifacts and a vendoring script | P0 | S | v1.0 | — | BE-32 | new |
| Thabit | 8 | DEP#9 | deployment | Runbook 3: Cloudflare Tunnels for staging and production, cache and security rules (no public web ports) | P0 | M | v1.0 | DEP#7, DEP-01, DEP#3 | — | update #9 |
| Thabit | 9 | DEP-02 | deployment | Runbook 8: object storage within the free 20 GB, software Vault keys, S3 credentials | P0 | M | v1.0 | DEP#7 | BE-21, DEP#8, DEP-04 | new |
| Thabit | 10 | DEP-13 | deployment | Runbook 11: Firebase project for FCM push on Android (service account and app configs) | P0 | S | v1.0 | — | BE-19, MOB-11 | new |
| Thabit | 11 | DEP-14 | deployment | Runbook 12: Authentica account, sender name and API key for phone codes | P0 | S | v1.0 | — | BE-20 | new |
| Thabit | 12 | AI-01 | ai-service | /capabilities: registry metrics, release date and registry name of the loaded model | P0 | S | v1.0 | — | BE-10 | new |
| Thabit | 13 | DEP#2 | deployment | Runbook 5: staging and production as two Compose projects on one ARM VM (memory budget, private AI) | P0 | L | v1.0 | DEP#7, DEP#3, AI-12, BE-04, BE-02, WEB-03, AI-07 | DEP#5, DEP#4, DEP#8, DEP#10, DEP-03 | update #2 |
| Thabit | 14 | AI-02 | ai-service | Per-request manual-review threshold for FR-D-5 governance | P0 | S | v1.0 | — | AI-03, BE-11a | new |
| Thabit | 15 | AI-04 | ai-service | Observability: Prometheus /metrics, JSON logs, job timing histograms | P0 | M | v1.0 | AI-07 | AI-06, DEP#10 | new |
| Thabit | 16 | DEP-03 | deployment | Runbook 9: continuous deployment to the staging project on merge to main | P0 | M | v1.0 | DEP#1, DEP#2 | DEP-07, DEP-10, DEP-04, DEP-08 | new |
| Thabit | 17 | AI-03 | ai-service | Threshold re-evaluation report from stored validation predictions | P0 | M | v1.0 | AI-02 | BE-11b | new |
| Thabit | 18 | DEP#6 | deployment | PDPL mapping, ROPA, retention schedule, consent texts and user agreement | P0 | M | v1.0 | — | BE-22, MOB-28 | update #6 |
| Thabit | 19 | DEP#8 | deployment | Runbook 6: free backups and a weekly tested restore on the VM (Postgres dumps, volume backups) | P0 | M | v1.0 | DEP#2, DEP-02 | DEP-04 | update #8 |
| Thabit | 20 | DEP-04 | deployment | Runbook 10: production project on the same VM, release with approval, rollback, and when to split | P0 | M | v1.0 | DEP-03, DEP#8, DEP-02 | AI-05, DEP-11 | new |
| Thabit | 21 | AI-09 | ai-service | Field photo set: printed dataset wounds with the 50 mm marker photographed by phones | P1 | S | v1.0 | — | — | new |
| Thabit | 22 | DEP#10 | deployment | Runbook 7: lightweight monitoring, logs, alerts and uptime (fits the free VM) | P1 | L | v1.0 | DEP#2, BE-27, AI-04 | AI-06 | update #10 |
| Thabit | 23 | DEP#5 | deployment | Local full-stack development environment (one command, seed, reset) | P1 | M | v1.0 | DEP#2 | — | update #5 |
| Thabit | 24 | DEP-09 | deployment | Threat model, incident response and 72-hour breach notification runbook | P1 | M | v1.0 | — | — | new |
| Thabit | 25 | AI-05 | ai-service | Model update without downtime (NFR-MAI-01) | P1 | M | v1.0 | DEP-04 | — | new |
| Thabit | 26 | DEP-11 | deployment | Go-live checklist and production launch | P0 | S | v1.0 | DEP-04, DEP-08, MOB-28, WEB-32 | — | new |
| Thabit | 27 | AI-06 | ai-service | Drift monitoring from production aggregates (SRS 5.6.3) | P2 | M | v1.0 | AI-04, DEP#10 | — | new |
| Thabit | 28 | DEP#4 | deployment | System documentation: C4 context/container, integration guide, cross-repo ADR index | P2 | M | v1.0 | DEP#2 | — | update #4 |
| Omar | 1 | BE#55 | backend | Send each analysis's ALG-02 version to the AI service as segmentation_version | P0 | S | v1.0 | — | BE-32, BE-18 | keep #55 |
| Omar | 2 | BE#57 | backend | Keep model_checksums and runtime_versions from failed AI jobs | P0 | S | v1.0 | — | BE-32 | keep #57 |
| Omar | 3 | BE#56 | backend | UC-SA-03 E3: a missed ALG-03 target must disable ALG-03, not block submissions | P1 | S | v1.0 | — | — | keep #56 |
| Omar | 4 | BE-01 | backend | OpenAPI as the single API contract: versioning, breaking-change check, published artifact | P0 | M | v1.0 | — | MOB-01, WEB-02 | new |
| Omar | 5 | BE-02 | backend | Health and readiness endpoints | P0 | S | v1.0 | — | DEP#2 | new |
| Omar | 6 | BE-04 | backend | Backend Dockerfile (web, worker, beat) and production entrypoint | P0 | M | v1.0 | DEP#1 | BE-03, DEP#2 | new |
| Omar | 7 | BE-03 | backend | Production settings hardening, security headers, structured logs, request-id propagation | P0 | M | v1.0 | BE-04 | — | new |
| Omar | 8 | BE-05 | backend | File URLs reachable by web and mobile (public storage endpoint, absolute media URLs) | P0 | S | v1.0 | — | BE-06, BE-21 | new |
| Omar | 9 | BE-31 | backend | Production bootstrap and staging test accounts | P0 | S | v1.0 | — | MOB-04, WEB-04 | new |
| Omar | 10 | BE-32 | backend | Sync vendored AI contract to the released version and use realistic fixtures | P0 | S | v1.0 | AI-10, BE#55, BE#57 | BE-10 | new |
| Omar | 11 | BE-06 | backend | Doctor visit detail: photo and mask URLs, measurement and applied threshold | P0 | M | v1.0 | BE-05 | BE-29, MOB-13, MOB-15, WEB-09 | new |
| Omar | 12 | BE-07 | backend | List a wound's visits for doctor and patient (submission history and image timeline) | P0 | M | v1.0 | — | MOB-09, WEB-07 | new |
| Omar | 13 | BE-39 | backend | Patient result: "wound not found" asks for a retake and says the doctor will review | P0 | S | v1.0 | — | MOB-08 | new |
| Omar | 14 | BE-08 | backend | Wound images: strip EXIF (GPS) and normalise orientation on upload | P0 | S | v1.0 | — | — | new |
| Omar | 15 | BE-09 | backend | Dev/staging command: seed a real dated analysis series through the AI pipeline | P0 | M | v1.0 | — | MOB-10, WEB-12 | new |
| Omar | 16 | BE-12 | backend | Step-up verification (re-enter OTP) for sensitive actions | P0 | M | v1.0 | — | BE-11a, BE-13, MOB-25 | new |
| Omar | 17 | BE-19 | backend | Push notifications in production: FCM (Android), device lifecycle, test push | P0 | S | v1.0 | DEP#3, DEP-13 | MOB-11 | new |
| Omar | 18 | BE-20 | backend | Phone codes through Authentica, email provider, and the OTP fallback prompt | P0 | M | v1.0 | DEP#3, DEP-01, DEP-14 | — | new |
| Omar | 19 | BE-37 | backend | Doctor dashboard summary endpoint (risk-ranked worklist) | P0 | M | v1.0 | — | MOB-18 | new |
| Omar | 20 | BE-11a | backend | FR-D-5: Super Admin changes the manual-review threshold (OTP, 40 % floor, audit, applied to analyses) | P0 | M | v1.0 | BE-12, AI-02 | BE-11b, WEB-26 | new |
| Omar | 21 | BE-13 | backend | Patient data export as background jobs (JSON/PDF) with status and download | P0 | M | v1.0 | BE-12 | MOB-25 | new |
| Omar | 22 | BE-21 | backend | Production object storage wiring and key rotation support | P0 | S | v1.0 | DEP-02, BE-05 | — | new |
| Omar | 23 | BE-11b | backend | Threshold change: doctor notification and re-evaluation report | P0 | M | v1.0 | BE-11a, AI-03 | WEB-26 | new |
| Omar | 24 | BE-14 | backend | Patient can cancel a pending deletion request | P0 | S | v1.0 | — | MOB-25 | new |
| Omar | 25 | BE-15 | backend | Prescriptions: COMPLETED status, detail fields and refill requests | P0 | M | v1.0 | — | MOB-22, MOB-32 | new |
| Omar | 26 | BE-10 | backend | AI model panel: join on checksum/registry_name and show metrics, threshold, tissue status | P0 | S | v1.0 | AI-01, BE-32 | WEB-26 | new |
| Omar | 27 | DEP-12 | deployment | System-level SRS divergence register (decisions that differ from the SRS PDF) | P1 | S | v1.0 | — | — | new |
| Omar | 28 | BE-34 | backend | Idempotency-Key on uploads (offline retries never double-submit) | P1 | S | v1.0 | — | — | new |
| Omar | 29 | BE-18 | backend | Bilingual clinician texts for AI decision reasons and warnings | P2 | S | v1.0 | BE#55 | — | new |
| Mohammad | 1 | MOB-01 | mobile | Generated API client from the backend OpenAPI; replace guessed Dio paths | P0 | M | v1.0 | BE-01 | MOB-04 | new |
| Mohammad | 2 | MOB-02 | mobile | Build flavors and platform config: dev/staging/prod, network security, no mock in production | P0 | S | v1.0 | — | MOB-03, MOB-11, MOB-30, MOB-34 | new |
| Mohammad | 3 | MOB-03 | mobile | Internal distribution: CI builds staging Android builds and ships them to testers | P0 | M | v1.0 | MOB-02 | MOB-28a | new |
| Mohammad | 4 | MOB-04 | mobile | Sign-in on the real backend: phone + password + OTP (SMS/email/authenticator), tokens, refresh, role routing | P0 | M | v1.0 | MOB-01, BE-31 | MOB-05, MOB-06, MOB-07, MOB-09, MOB-12, MOB-14, MOB-17, MOB-20, MOB-21, MOB-22, MOB-23 | new |
| Mohammad | 5 | MOB-05 | mobile | Sign-in security: CAPTCHA after 3 failures, remember device 30 days, biometric unlock, 15-min timeout | P0 | M | v1.0 | MOB-04 | — | new |
| Mohammad | 6 | MOB-28a | mobile | Google Play Console: app, Play App Signing, internal testing, and a 14-day closed test with 12 testers | P0 | M | v1.0 | MOB-03 | MOB-28 | new |
| Mohammad | 7 | MOB-07 | mobile | Patient photo upload on the real backend (fields, duplicate 409, idempotency, offline queue) | P0 | M | v1.0 | MOB-04 | MOB-08 | new |
| Mohammad | 8 | MOB-08 | mobile | Patient result screen on the real backend (5 states, tips, overlay, disclaimer) | P0 | M | v1.0 | MOB-07, BE-39 | MOB-26, MOB-27 | new |
| Mohammad | 9 | MOB-09 | mobile | Patient wounds list and submission history (filters, thumbnails, AI summary) | P0 | M | v1.0 | BE-07, MOB-04 | MOB-10, MOB-26 | new |
| Mohammad | 10 | MOB-11 | mobile | Push notifications with FCM on Android (setup and device registration) | P0 | M | v1.0 | MOB-02, BE-19, DEP-13 | MOB-24, MOB-35 | new |
| Mohammad | 11 | MOB-12 | mobile | Doctor: patient list, search/filters, profile and register new patient | P0 | M | v1.0 | MOB-04 | MOB-13, MOB-19, MOB-31, MOB-32, MOB-33 | new |
| Mohammad | 12 | MOB-13 | mobile | Doctor: capture/upload for a patient and analysis status (6 statuses, 10 reasons) | P0 | M | v1.0 | MOB-12, BE-06 | MOB-15, MOB-18 | new |
| Mohammad | 13 | MOB-15 | mobile | Doctor: AI result view (overlay toggle, area ± uncertainty, dimensions, confidence, risk factors, versions) | P0 | M | v1.0 | MOB-13, BE-06 | MOB-16 | new |
| Mohammad | 14 | MOB-16 | mobile | Doctor: review (approve / override with justification) and side-by-side | P0 | M | v1.0 | MOB-15 | MOB-27 | new |
| Mohammad | 15 | MOB-24 | mobile | Deep links, in-app notification centre and read state | P0 | M | v1.0 | MOB-11 | — | new |
| Mohammad | 16 | MOB-18 | mobile | Doctor: dashboard and worklist (needs review, failed with retry) | P0 | M | v1.0 | MOB-13, BE-37 | — | new |
| Mohammad | 17 | MOB-19 | mobile | Doctor: wound progression timeline and deterioration alerts | P0 | M | v1.0 | MOB-12 | — | new |
| Mohammad | 18 | MOB-06 | mobile | Password reset and change on the real backend | P1 | S | v1.0 | MOB-04 | — | new |
| Mohammad | 19 | MOB-10 | mobile | Patient progression chart with the five ALG-04 statuses | P1 | S | v1.0 | MOB-09, BE-09 | — | new |
| Mohammad | 20 | MOB-14 | mobile | Patient appointments on the backend (request, cancel, history, reminders) | P1 | S | v1.0 | MOB-04 | — | new |
| Mohammad | 21 | MOB-17 | mobile | Patient care plan on the backend (versions, acknowledgement) | P1 | S | v1.0 | MOB-04 | — | new |
| Mohammad | 22 | MOB-25 | mobile | Patient privacy on the backend: consents, export jobs, access log, deletion request and cancel, step-up | P1 | M | v1.0 | BE-12, BE-13, BE-14 | — | new |
| Mohammad | 23 | MOB-26 | mobile | Offline read-only access to recent history and results (FR-P-7.2) | P1 | M | v1.0 | MOB-09, MOB-08 | — | new |
| Mohammad | 24 | MOB-22 | mobile | Patient prescriptions: list, detail, PDF download, expiry, refill request | P1 | M | v1.0 | MOB-04, BE-15 | — | new |
| Mohammad | 25 | MOB-23 | mobile | Patient profile and preferences (medical background, photo, language, notification preferences) | P1 | S | v1.0 | MOB-04 | — | new |
| Mohammad | 26 | MOB-29 | mobile | Arabic/RTL, accessibility and plain-language audit of all new screens | P1 | S | v1.0 | — | — | new |
| Mohammad | 27 | MOB-27 | mobile | Integration tests against staging on an Android device matrix | P0 | M | v1.0 | MOB-08, MOB-16 | MOB-28 | new |
| Mohammad | 28 | MOB-28 | mobile | Google Play production release: listing AR/EN, data safety, review, rollout | P0 | M | v1.0 | MOB-28a, MOB-27, DEP#6 | MOB-36, DEP-11 | new |
| Mohammad | 29 | MOB-30 | mobile | Crash and error reporting (privacy-safe) | P2 | S | v1.0 | MOB-02 | — | new |
| Mohammad | 30 | MOB-34 | mobile | iOS builds: signing, flavors and TestFlight | P0 | M | v1.1 | MOB-02 | MOB-35, MOB-36 | new |
| Mohammad | 31 | MOB-35 | mobile | iOS push notifications: APNs key in Firebase, capabilities, permission flow | P0 | S | v1.1 | MOB-34, MOB-11 | MOB-36 | new |
| Mohammad | 32 | MOB-36 | mobile | App Store release: listing, privacy nutrition labels, review, iOS device tests | P1 | M | v1.1 | MOB-34, MOB-35, MOB-28 | — | new |
| Mansour | 1 | WEB-06 | web | Doctor: patient list (search, filters, risk colours) and register patient on the API | P0 | M | v1.0 | WEB-02 | WEB-07 | new |
| Mansour | 2 | WEB-08 | web | Doctor: wound photo upload on the API (8 MP, 50 mm marker, duplicate confirm, queue position) | P0 | M | v1.0 | WEB-02 | — | new |
| Mansour | 3 | WEB-11 | web | Doctor: analyses needing attention, retry, and failure notifications | P0 | S | v1.0 | WEB-02 | — | new |
| Mansour | 4 | WEB-13 | web | Doctor: alerts panel, acknowledge with justification, risk-ranked dashboard | P0 | M | v1.0 | WEB-02 | — | new |
| Mansour | 5 | WEB-07 | web | Doctor: patient profile with wounds and image timeline | P0 | M | v1.0 | WEB-06, BE-07 | WEB-15, WEB-16, WEB-18, WEB-17 | new |
| Mansour | 6 | BE-26 | backend | Clinic-scoped account event log for Clinic Admins | P0 | S | v1.0 | — | WEB-22 | new |
| Mansour | 7 | WEB-10 | web | Doctor: review (approve / override with justification), side-by-side, feedback consent | P0 | M | v1.0 | WEB-09 | WEB-30, WEB-32 | new |
| Mansour | 8 | DEP-10 | deployment | Cross-repo end-to-end smoke after every staging deploy | P0 | M | v1.0 | DEP-03 | — | new |
| Mansour | 9 | WEB-20 | web | Clinic Admin: doctors list, add doctor, deactivate on the API | P0 | M | v1.0 | WEB-04 | WEB-21, WEB-22 | new |
| Mansour | 10 | WEB-21 | web | Clinic Admin: reassign patients (single, bulk, unassigned) | P0 | S | v1.0 | WEB-20 | — | new |
| Mansour | 11 | WEB-15 | web | Doctor: SOAP clinical notes on the API | P1 | M | v1.0 | WEB-07 | — | new |
| Mansour | 12 | WEB-18 | web | Doctor: appointments and next-visit reminders on the API | P1 | M | v1.0 | WEB-07 | — | new |
| Mansour | 13 | WEB-17 | web | Doctor: care plan editor and shared notes control | P1 | M | v1.0 | WEB-07 | — | new |
| Mansour | 14 | WEB-22 | web | Clinic Admin: statistics with PDF export and account events log | P1 | M | v1.0 | WEB-20, BE-26 | — | new |
| Mansour | 15 | BE-22 | backend | Retention jobs from the PDPL retention schedule | P1 | M | v1.0 | DEP#6 | — | new |
| Mansour | 16 | BE-24 | backend | Security fixes from scans and review (ZAP, dependency audit) | P1 | S | v1.0 | DEP-07 | — | new |
| Mansour | 17 | DEP-08 | deployment | Load and performance tests (NFR-PERF, NFR-SCA) without hurting production on the shared VM | P0 | M | v1.0 | DEP-03 | BE-23, DEP-11 | new |
| Mansour | 18 | BE-23 | backend | Performance fixes from the staging load test | P1 | M | v1.0 | DEP-08 | — | new |
| Mansour | 19 | WEB-31 | web | Arabic/RTL, accessibility and plain-language audit (all pages) | P1 | M | v1.0 | — | — | new |
| Mansour | 20 | WEB-32 | web | Playwright E2E suite against staging (all actors) | P0 | M | v1.0 | WEB-10, WEB-23 | WEB-34, DEP-11 | new |
| Mansour | 21 | WEB-34 | web | Cross-browser verification (latest two Chrome, Firefox, Safari) | P1 | S | v1.0 | WEB-32 | — | new |
| Mansour | 22 | BE-30 | backend | Consented feedback dataset export for retraining (anonymised) | P2 | S | v1.0 | — | — | new |
| Mansour | 23 | BE-42 | backend | Structured patient notes on upload (pain level, odour, discharge colour) | P2 | S | v1.0 | — | — | new |
| Ahmed | 1 | WEB-01 | web | Green CI on main and repo hygiene | P0 | S | v1.0 | — | — | new |
| Ahmed | 2 | WEB-02 | web | Generated API client from the backend OpenAPI, data layer, mocks only in tests | P0 | M | v1.0 | BE-01 | WEB-04, WEB-06, WEB-08, WEB-11, WEB-13, WEB-09, WEB-12 | new |
| Ahmed | 3 | WEB-03 | web | Production container: static build on NGINX, runtime config, CSP | P0 | S | v1.0 | DEP#1 | WEB-33, DEP#2 | new |
| Ahmed | 4 | WEB-04 | web | Real sign-in: password, OTP (SMS/email/authenticator), resend, CAPTCHA, lockout, timeout, role routing | P0 | M | v1.0 | WEB-02, BE-31 | WEB-05, WEB-14, WEB-19, WEB-20, WEB-24, WEB-23, WEB-25, WEB-27 | new |
| Ahmed | 5 | WEB-05 | web | Account activation, invitations, authenticator setup, password reset and change | P0 | M | v1.0 | WEB-04 | WEB-28 | new |
| Ahmed | 6 | WEB-09 | web | Doctor: AI result view on the API (statuses, reasons, overlay toggle, measurement, risk, versions) | P0 | M | v1.0 | WEB-02, BE-06 | WEB-10 | new |
| Ahmed | 7 | WEB-12 | web | Doctor: progression timeline on the API (chart, healing rate, colours, alerts, model-change warning) | P0 | M | v1.0 | WEB-02, BE-09 | — | new |
| Ahmed | 8 | BE-27 | backend | Backend metrics endpoint (django-prometheus, Celery queue metrics) | P0 | S | v1.0 | — | DEP#10 | new |
| Ahmed | 9 | BE-25 | backend | Super Admin doctor lifecycle across clinics: deactivate, archive, soft delete | P0 | M | v1.0 | — | WEB-24 | new |
| Ahmed | 10 | DEP-07 | deployment | Security scanning in CI: images, dependencies, secrets, DAST baseline | P0 | M | v1.0 | DEP#1, DEP-03 | BE-24 | new |
| Ahmed | 11 | BE-16 | backend | MFA manual recovery workflow when every OTP method fails | P0 | M | v1.0 | — | WEB-29 | new |
| Ahmed | 12 | WEB-23 | web | Super Admin: clinics directory, provisioning and lifecycle (activate/deactivate/archive) | P0 | M | v1.0 | WEB-04 | WEB-32 | new |
| Ahmed | 13 | BE-17 | backend | Breach notification to affected patients within 72 hours | P0 | M | v1.0 | — | WEB-29 | new |
| Ahmed | 14 | WEB-33 | web | Security and performance budget: CSP compliance, no unsafe-inline, bundle budget, error monitoring | P1 | S | v1.0 | WEB-03 | — | new |
| Ahmed | 15 | WEB-14 | web | Notification centre with deep links (all roles) | P1 | S | v1.0 | WEB-04 | — | new |
| Ahmed | 16 | WEB-16 | web | Doctor: prescriptions upload and list (expiry, completed, refill requests) | P1 | M | v1.0 | WEB-07 | — | new |
| Ahmed | 17 | WEB-19 | web | Doctor: secure messaging on the API | P1 | M | v1.0 | WEB-04 | — | new |
| Ahmed | 18 | WEB-24 | web | Super Admin: cross-clinic doctors (create, deactivate, archive, soft delete) | P1 | S | v1.0 | WEB-04, BE-25 | — | new |
| Ahmed | 19 | WEB-25 | web | Super Admin: system dashboard (5-minute refresh, date range, PDF export) | P1 | S | v1.0 | WEB-04 | — | new |
| Ahmed | 20 | MOB-20 | mobile | Doctor: messaging with patients | P1 | S | v1.0 | MOB-04 | — | new |
| Ahmed | 21 | WEB-27 | web | Super Admin: audit log viewer with filters and CSV/PDF export | P1 | S | v1.0 | WEB-04 | — | new |
| Ahmed | 22 | MOB-21 | mobile | Patient messaging with the assigned doctor | P1 | M | v1.0 | MOB-04 | — | new |
| Ahmed | 23 | WEB-26 | web | Super Admin: AI model panel and confidence-threshold governance | P1 | M | v1.0 | BE-10, BE-11a, BE-11b | — | new |
| Ahmed | 24 | WEB-28 | web | Super Admin: team invitations and Full/Read-only roles | P1 | S | v1.0 | WEB-05 | — | new |
| Ahmed | 25 | WEB-29 | web | Super Admin: data requests, MFA recovery requests and breach notification console | P1 | M | v1.0 | BE-16, BE-17 | — | new |
| Ahmed | 26 | BE-29 | backend | Clinician-corrected wound boundary (FR-D-7) with recomputed area | P2 | M | v1.0 | BE-06 | WEB-30 | new |
| Ahmed | 27 | WEB-30 | web | Doctor: corrected wound boundary editor (FR-D-7) | P2 | M | v1.0 | WEB-10, BE-29 | — | new |
| Ahmed | 28 | MOB-31 | mobile | Doctor (mobile): SOAP clinical notes | P2 | M | v1.0 | MOB-12 | — | new |
| Ahmed | 29 | MOB-32 | mobile | Doctor (mobile): prescription upload and next-visit reminder | P2 | M | v1.0 | MOB-12, BE-15 | — | new |
| Ahmed | 30 | MOB-33 | mobile | Doctor (mobile): care plan editor and appointment requests (confirm/reject/reschedule) | P2 | M | v1.0 | MOB-12 | — | new |
