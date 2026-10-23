# A. Gap list against the full SRS

**Baseline:** `iltiam-ai-service/docs/SRS.pdf` (2026-10-18, 177 pp.). It is newer than the identical copies in iltiam-backend and iltiam-mobile (`GP02_SRS_final.pdf`, 2026-10-15). The repos were read at the HEADs of 2026-10-23: ai `992ff76`, backend `63d4ad6`, web `200651f`, mobile `544b9ec`, deployment `ffd12d4`.

**Status values:**
- **done**: real, end to end in this layer.
- **mock**: the UI exists, but runs on mock data (web: all of it; mobile: by default).
- **partial**: some parts missing.
- **missing**: nothing exists.
- **—**: not this layer's job.

**Columns:**
- "Mob-P" is the mobile patient app.
- "Mob-D" is the mobile doctor app. The SRS (Table 8) gives doctors the web only; the doctor mobile app is a scope extension (owner decision), recorded in DEP-12.
- Plan IDs refer to `issues/` (see `issue_index.md`).

## Super Admin (FR-SA)

| Req | Backend | Web | AI / Deploy | Gap and issues |
|---|---|---|---|---|
| FR-SA-1 login + MFA, lockout, 15-min timeout, audit | done (#3, #16) | mock | — | WEB-04 |
| FR-SA-2 RBAC loaded after login; role change ends session | done (#4, #29) | mock (role nav) | — | WEB-04 |
| FR-SA-3 invitation-based Super Admins (24 h token, MFA setup, policies) | done (#29) | mock | — | WEB-05, WEB-28 |
| FR-SA-4 create clinic (unique name, activation email) | done (#22) | mock | DEP-01 (email domain) | WEB-23, BE-20 (email provider) |
| FR-SA-5 activate / deactivate / archive, archive policy | done (#22) | mock | — | WEB-23 |
| FR-SA-6 create doctors for any clinic; deactivate, archive, soft delete (Table 11/15) | partial: create done; Super Admin status changes and soft delete missing | mock | — | BE-25, WEB-24 |
| FR-SA-7 system dashboard (5-min refresh, PDF) | done (#27) | mock | — | WEB-25 |
| FR-SA-8 AI model version, Dice/IoU/accuracy, history, override rate | partial: panel join never matches the real `/capabilities`, so metrics are null | mock | AI partial: no `metrics`/`released_at` | AI-01, BE-10, BE-32, WEB-26 |
| FR-SA-9 MFA fallbacks: SMS → email → authenticator → manual recovery; SMS failure detected in 30 s | partial: own codes + email/authenticator done; SMS provider not configured (Twilio coded, no account); 30-s fallback and manual recovery missing | mock | DEP-14 (Authentica account) | BE-20 (Authentica), BE-16, WEB-04, WEB-29 |
| FR-SA-10 audit logs: filters, export, tamper-proof, ≥ 2-year retention | done (#13); retention job missing | mock | DEP#6 (schedule) | BE-22, WEB-27 |
| FR-SA-11 Full / Read-only sub-roles | done (#29) | mock | — | WEB-28 |
| UC-SA-01/02/03 | as above | mock | — | WEB-23, WEB-26; #56 (E3) |

## Clinic Admin (FR-CA)

| Req | Backend | Web | Gap and issues |
|---|---|---|---|
| FR-CA-1 login + OTP | done | mock | WEB-04 |
| FR-CA-2 doctors list | done (#23) | mock | WEB-20 |
| FR-CA-3 add doctor (unique phone, pending activation) | done (#23) | mock | WEB-20, WEB-05 (activation page) |
| FR-CA-4 anonymised statistics + PDF | done (#27) | mock | WEB-22 |
| FR-CA-5 clinic-scoped account event log | **missing**: `/api/audit-logs/` is Super Admin only | mock | BE-26, WEB-22 |
| FR-CA-6 no hard delete; deactivate / archive / soft delete | partial: soft delete missing; Table 15 says Clinic Admin may only deactivate (conflict recorded in DEP-12) | mock | BE-25, WEB-20 |
| FR-CA-7 reassign (single, bulk, Unassigned) | done (#23) | mock | WEB-21 |
| UC-CA-01/02/03 | as above | mock | — |

## Doctor (FR-D)

| Req | Backend | Web | Mob-D | AI | Gap and issues |
|---|---|---|---|---|---|
| FR-D-1 login phone + password + OTP | done | mock | mock | — | WEB-04, MOB-04 |
| FR-D-2 create patient (OTP to patient) | done (#5) | mock | mock | — | WEB-06, MOB-12 |
| FR-D-3 search + full profile (submissions, results, risk), dashboard < 3 s | partial: no visit list per wound, no dashboard summary | mock | mock | — | BE-07, BE-37, WEB-06, WEB-07, WEB-13, MOB-12, MOB-18 |
| FR-D-4 upload (JPEG/PNG, 8 MP, 10 MB auto-compress, marker confirmation, queue) | done (#6, #9, #19); EXIF (GPS) not stripped | mock (wrong "1 cm marker" text) | mock (guessed paths) | done | BE-08, WEB-08, MOB-13 |
| FR-D-5 result: overlay toggle, area ± uncertainty, L/W/P, confidence, risk, version; threshold governance (OTP, audit, re-evaluation, doctor notice, 40 % floor) | partial: no photo/mask URLs, measurement only in raw JSON, **governance missing** | mock | mock | done; per-request threshold and re-evaluation report missing | BE-06, BE-11a, BE-11b, AI-02, AI-03, WEB-09, WEB-26, MOB-15 |
| FR-D-6 timeline: image timeline, area chart, healing rate, colours, plateau/worsening | partial: progression done (#10); image timeline missing; same-day uploads collapse (dev seed needed) | mock | mock | done (ALG-04) | BE-07, BE-09, WEB-07, WEB-12, MOB-19 |
| FR-D-7 approve / override with justification, side-by-side, corrected boundary, feedback dataset | partial: review done (#12); corrected boundary and feedback export missing | mock | **missing** (no review on mobile) | — | BE-29, BE-30, WEB-10, WEB-30, MOB-16 |
| FR-D-8 SOAP notes | done (#20) | mock | **missing** | — | WEB-15, MOB-31 |
| FR-D-9 signed PDF prescription | done (#24) | mock | **missing** | — | WEB-16, MOB-32 |
| FR-D-10 next-visit reminder | done (#30) | mock | **missing** | — | WEB-18, MOB-32 |
| FR-D-11 deterioration alerts (≥ 10 %, High, plateau 14 d), SMS/push for critical | done (#11, #25) | mock | mock | done (flags) | WEB-13, MOB-19, BE-19, BE-20 |
| FR-D-12 retries, error codes, 30 s timeout → pending manual review, retry | done (#26) | mock | mock | done | WEB-11, MOB-18 |
| FR-D-13 secure messaging (12 months, auto-reply, attachments) | done (#32) | mock | mock | — | WEB-19, MOB-20 |
| UC-DR-01/02/03 | as above | mock | mock | done | — |

## Patient (FR-P)

| Req | Backend | Mob-P | Gap and issues |
|---|---|---|---|
| FR-P-1.1 phone + password + OTP, lockout, CAPTCHA after 3, biometric shortcut, remember device 30 d, timeout | done (#16); decision: keep the password (DEP-12) | **mock** (auth always mock, no password step) | MOB-04, MOB-05 |
| FR-P-1.2 profile, medical background, photo, language, notification preferences | done (#33) | mock | MOB-23 |
| FR-P-1.3 password reset by OTP | done (#17) | mock (wrong paths) | MOB-06 |
| FR-P-2.1 guided capture: marker overlay and confirmation, blur/light/coverage, 8 MP, torch | — (ALG-01 server side done) | done in UI (fake camera in tests); needs device QA | MOB-07, MOB-27 |
| FR-P-2.2 upload: 10 MB, offline queue, duplicate prompt, 5 s on 4G, structured notes | done (#6, #19); structured notes and idempotency missing | mock (wrong fields) | BE-42, BE-34, MOB-07 |
| FR-P-2.3 history with filters, thumbnails, 5 statuses | partial: no visit list | mock (3 statuses) | BE-07, MOB-09, MOB-10 |
| FR-P-3.1 plain-language result, overlay, confidence text, disclaimer | done (#18); decision: retake + doctor review for "wound not found" | mock (crashes when risk is null) | BE-39, MOB-08 |
| FR-P-3.2 push/SMS, deep links, AR/EN, per-type opt-out, reminder frequency | done (#25); production FCM config missing | partial (fake push, no Firebase files) | DEP-13, BE-19, MOB-11 (Android, v1.0), MOB-35 (iOS, v1.1), MOB-24, MOB-23 |
| FR-P-4.1 appointments (max 3, cancel ≥ 2 h, T-24 h/T-1 h reminders) | done (#30) | local store only | MOB-14 |
| FR-P-5.1 prescriptions: Active/Completed/Expired, detail, PDF, refill, expiry reminder | partial: COMPLETED and refill missing | mock | BE-15, MOB-22, WEB-16 |
| FR-P-5.2 care plan, shared notes, acknowledgement, versions | done (#31) | mock | MOB-17, WEB-17 |
| FR-P-6.1 messaging (TLS 1.3, AES-256 at rest, no delete, auto-reply) | done (#32) | mock | MOB-21; TLS 1.3 in DEP#9 |
| FR-P-7.1 export JSON/PDF, consent withdrawal, deletion within 30 d, access log, breach notice in 72 h, training-data exclusion | partial: sync export, consent, deletion, access log done (#35); step-up, export jobs, deletion cancel, breach notice, training exclusion missing | mock | BE-12, BE-13, BE-14, BE-17, BE-30, MOB-25, WEB-29, DEP#6, DEP-09 |
| FR-P-7.2 offline capture (10 queued) and read-only recent data | — | partial: queue done; read-only cache missing | MOB-26 |
| UC-PT-01/02/03 | as above | mock | — |

## AI service (FR-AI, Table 40a)

| Req | Status | Issues |
|---|---|---|
| FR-AI-01 quality gate | done | — |
| FR-AI-02 marker required | done | — |
| FR-AI-03 SegFormer-B2 mask + confidence | done (models-v2.0.0) | — |
| FR-AI-04 px → cm² | done | — |
| FR-AI-05 MANUAL_REVIEW below threshold | done (0.94 for v2, per model); per-request threshold for governance missing | AI-02 |
| FR-AI-06 progression | done (`progression@1.3.0`) | — |
| FR-AI-07 risk | done (`risk@1.1.0`) | — |
| FR-AI-08 versions in every result | done | — |
| FR-AI-09 tissue, experimental | done; off by default (ADR-0008, #129: v0.2.0 missed its ship rule) | — |
| FR-AI-10 L/W/P + uncertainty band | done (`measurement@1.2.0`) | — |
| §5.6.3 versioned registry, drift monitoring | registry done; drift monitoring missing | AI-06 |
| Contract delivery to the backend | done, but the backend copy is 12 fields behind | AI-10, BE-32 |

## Non-functional requirements

| NFR | Status | Where | Issues |
|---|---|---|---|
| PERF-01 analysis ≤ 10 s (owner target 4 s) | likely met: laptop compute 0.68 s (ALG-03 off) / 1.46 s (on), ≈ 2.6–3.7 s end to end; not measured on a server | AI / deploy | AI-12, DEP-08 |
| PERF-02 web page ≤ 3 s at 50 users | not measured on staging (Locust harness exists locally) | backend / web | DEP-08, BE-23, WEB-33 |
| PERF-03 10 MB upload ≤ 5 s on 4G | not measured | mobile | DEP-08, MOB-07 |
| PERF-04 progression for 50 records ≤ 5 s | not measured | backend | DEP-08 |
| REL-01 97 % uptime / 30 days | **missing** (no server, no monitoring) | deploy | DEP#10 |
| REL-02 no lost image or result | partial: AI Redis AOF and backend storage; backups missing | deploy | DEP#8 |
| REL-03 failures detected, logged, image kept for re-processing | done: AI logs (#121); backend keeps the original and offers retry (#26) | — | — |
| REL-04 daily backups, RTO 4 h, weekly test restore | **missing** | deploy | DEP#8 |
| AVA-01 24/7 | **missing** (no production) | deploy | DEP#2, DEP-04 |
| AVA-02 offline capture, no data loss | done in the mobile queue; verify with the real backend | mobile | MOB-07 |
| SEC-01 password policy | done | backend | — |
| SEC-02 15-min timeout (web and mobile) | backend done; clients mock | clients | WEB-04, MOB-05 |
| SEC-03 lockout 10 min after 5 | done | backend | — |
| SEC-04 AES-256 at rest, KMS, yearly rotation | dev only (MinIO static key); production missing | deploy / backend | DEP-02, BE-21 |
| MAI-01 model update without downtime | **missing** | AI / deploy | AI-05, DEP-04 |
| MAI-02 audit of admin actions, AI model changes, security events | done (#13); threshold changes to add | backend | BE-11a |
| MAI-03 determinism | done | AI | — |
| MAI-04 provenance incl. failed analyses | AI done (#121); backend in progress (#57) | backend | #57, BE-32 |
| POR-01 Android 10+, iOS 14+ | CI builds a debug APK only; no iOS build | mobile | Android in v1.0: MOB-03, MOB-27, MOB-28a, MOB-28. iOS in v1.1: MOB-34, MOB-35, MOB-36 |
| POR-02 Chrome, Firefox, Safari (latest two) | not verified | web | WEB-34 |
| USA-01 first upload ≤ 5 min | not verified | mobile | MOB-29 |
| USA-02 highest-risk patient ≤ 15 s | not verified; dashboard composed client-side | web / mobile / backend | BE-37, WEB-13, MOB-18 |
| USA-03 plain errors + corrective action | backend envelope done (Arabic/English); clients must surface it | clients | WEB-02, MOB-01 |
| USA-04 Arabic/English + RTL | done in UIs; keep it while wiring | clients | WEB-31, MOB-29 |
| SCA-01 500 patients | local load test done (backend #34); not on staging | deploy | DEP-08 |
| SCA-02 60,000 images per year | not verified | deploy / backend | DEP-08, BE-23 |
| ACC-01/02 Dice ≥ 0.80 in-domain, ≥ 0.55 cross-dataset, IoU ≥ 0.65 | met (clean test 0.8875; DFUC2022 0.5865); validation set < 1,000 images (SRS B5) | AI | — |
| ACC-03 classification ≥ 90 % | re-scoped by ADR-0008; ALG-03 experimental and off | AI | #56 (backend side) |

## Cross-cutting (SRS §5, §13, §17)

| Topic | Status | Issues |
|---|---|---|
| One API contract, generated clients | **missing**: the web has a hand-kept mirror, mobile guessed its paths | BE-01, WEB-02, MOB-01 |
| Contract AI ↔ backend | done, drifting | AI-10, BE-32, #55, #57 |
| CI per repo | ai, backend, mobile green; **web red since 2026-10-19** | WEB-01, DEP#1 |
| Regression on every merge ≤ 15 min (§5.7) | ai, backend, mobile have suites; cross-repo E2E missing | DEP-10, WEB-32, MOB-27 |
| Security testing (ZAP, static analysis, §5.8) | missing | DEP-07, BE-24 |
| Staging that mirrors production (§17) | **missing** | DEP#7 (OCI Riyadh), DEP-01 + DEP#9 (Cloudflare, Tunnel), DEP#2, DEP-03 |
| Observability | missing | DEP#10, AI-04, BE-27 |
| PDPL documents (ROPA, retention, consent texts, threat model, incident response) | missing (deployment #6 open) | DEP#6, DEP-09 |
| SRS divergence register (system level) | AI only | DEP-12 |
