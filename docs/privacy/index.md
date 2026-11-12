# PDPL documents

- **Issue:** iltiam/iltiam-deployment#6. **SRS:** FR-P-7.1, NFR-SEC-04, FR-SA-10.
- **Status:** **draft, written 2026-11-13. It needs review by the supervisor (legal content) and a native Arabic speaker (the Arabic texts) before merge.**
- **Law:** the Saudi Personal Data Protection Law (PDPL) and its Implementing Regulations. These documents cite no article numbers. Every legal basis and legal claim that hasn't been checked is marked **TO CONFIRM**, with a number from the register below.

> **This repository is public.** These pages hold no namespace, OCID, key, real phone number or personal data. Bucket names and the public domain `iltiamcare.com` are already public in the runbooks.

## The documents

| Document | What it holds |
|---|---|
| [Record of processing (ROPA)](ropa.md) | Each data class: what, whose, why, legal basis, where it is stored, who processes it, how long it's kept |
| [Retention schedule](retention.md) | How long each data class is kept, and the job or manual process that enforces it |
| [Rights map](rights-map.md) | Each PDPL right → app screen → backend endpoint → backend test |
| [Consent texts](consent-texts.md) | The AI analysis and feedback dataset consents, Arabic and English, with version IDs |
| [Privacy notice](privacy-notice.md) | For patients and staff, Arabic and English, `privacy-notice-v1` |
| [Terms of use](terms-of-use.md) | Patient terms (`terms-v1`) and staff policies (`staff-policies-v1`), Arabic and English |
| [Play data safety](play-data-safety.md) | The answers for Google Play Console's Data safety form |
| [Backups and restores stay in Riyadh](restore-location.md) | The record that dumps and restore tests never leave the Riyadh VM and buckets |

## Decisions

| Date | Decision |
|---|---|
| 2026-11-09 | The backend's retention schedule (iltiam-backend `docs/retention.md`, PR #108) is adopted as the base of [retention.md](retention.md) |
| 2026-11-13 | **#6 closes when these documents are merged.** Showing the texts in the apps is tracked in iltiam/iltiam-web#29 (web) and iltiam/iltiam-mobile#44 (Android) |
| 2026-11-13 | Each user-facing text has a version ID (`ai-consent-v1`, `feedback-consent-v1`, `privacy-notice-v1`, `terms-v1`, `staff-policies-v1`). A changed text gets a new ID; the apps show the words of the ID they record |
| 2026-11-13 | Doctor accounts are never deleted, only deactivated, so that medical records keep their author (medical data integrity) |
| until after the demo | `RETENTION_ENFORCE` stays off on staging: the retention job only counts. Production turns it on once these documents are approved |

## Findings while writing

These are facts found in the code on 2026-11-13. They are not legal questions, so they aren't in the register.

1. **Push notifications carry health-related text through Google.** Firebase Cloud Messaging receives each notification's title and text, and some say, for example, "The result of your latest wound photo shows a high risk" (iltiam-backend `apps/notifications/catalog.py`). No measurement, photo or diagnosis is sent. See TC-20.
2. **Export files are never removed from storage.** The backend refuses a download after 7 days and expects a bucket lifecycle rule on the `exports/` prefix of `iltiam-<SHORT>-reports`. That rule doesn't exist (Runbook 8, section 8 has only two rules). Until it is added, [retention.md](retention.md) names a monthly manual clean-up.
3. **The mobile app downloads its fonts from Google at run time** (`google_fonts` without bundled fonts), so Google sees the phone's IP address when the app first opens. The web app bundles its fonts. Bundling the fonts in the app removes this; see TC-23.
4. **The backend records when a consent was given or withdrawn, not which text version.** `Patient.ai_analysis_consent_at` and `ai_feedback_consent_at` hold a time only. Storing the version ID is a backend follow-up ([consent-texts.md](consent-texts.md)).
5. **Anonymisation keeps wound photos, notes and message text.** They can still identify a person (a face, a tattoo, a name typed in a message). See TC-12 and [the rights map](rights-map.md#6-destruction-deletion-done-as-anonymisation).
6. **Super Admin screens for deletion requests and breach incidents don't exist on the web yet.** The rights work through the API (`/api/data-requests/`, `/api/breach-incidents/`) and `manage.py send_breach_notice`.

## TO CONFIRM register

Each item needs an answer from the supervisor, or someone who knows the PDPL, before production. The pages mark each place with its number.

| # | Question | Where |
|---|---|---|
| TC-1 | Who is the **controller**: each clinic, the ILTIAM team, or both? Which legal entity and address does the privacy notice name? | ROPA, privacy notice, terms |
| TC-2 | The **legal basis** for processing patients' health data to provide care (consent at enrolment, or a health-care basis) | ROPA rows 3 to 8 |
| TC-3 | The legal basis for **AI analysis** of wound photos: explicit consent (`ai-consent-v1`) | ROPA row 5, consent texts |
| TC-4 | The legal basis for the **AI feedback dataset** (consent, `feedback-consent-v1`), and whether the exported dataset (photos, masks, values, no identifiers) counts as anonymised under the PDPL | ROPA row 14, consent texts |
| TC-5 | The legal basis for **staff account data, sign-in records and audit logs** | ROPA rows 1, 2, 11 |
| TC-6 | That health data is **sensitive data** under the PDPL, and what extra duties follow (ADR-0004 states it; no article checked) | ROPA, privacy notice |
| TC-7 | **Breach notification:** the 72-hour deadline to the regulator (SDAIA), and when data subjects must be told. The source in the Implementing Regulations | Rights map row 7, privacy notice |
| TC-8 | **Transfers outside the Kingdom:** Cloudflare (TLS decrypted at its edge, Email Routing), Google (FCM, the privacy@ mailbox, fonts). Which transfer rule applies, and whether Cloudflare's paid Data Localization Suite is required | ROPA processors, privacy notice |
| TC-9 | **Clinical records kept permanently** (SRS FR-P-7.1, FR-D-9) versus a fixed medical-record retention period under Saudi health regulations | Retention rows 1 and 2 |
| TC-10 | Audit logs kept **at least 2 years** (SRS FR-SA-10): is there a maximum? | Retention row 4 |
| TC-11 | **Response time** to rights requests: the SRS gives 30 days for deletion requests (FR-P-7.1). Is that the PDPL deadline, and does it apply to access and correction too? | Rights map, privacy notice |
| TC-12 | Does **anonymising** a patient's clinical record, instead of deleting it, satisfy the right to destruction? | Rights map row 6, privacy notice |
| TC-13 | **Uptime pinger:** which service (ADR-0004 plans "a hosted pinger"), and that it receives no personal data | ROPA processors |
| TC-14 | **Processor contracts:** are data processing terms in place with Oracle, Cloudflare, Authentica and Google, and are their standard terms enough? | ROPA processors |
| TC-15 | **Processors' own logs:** how long Authentica (its SMS logs show messages), Cloudflare, Firebase and OCI Email Delivery keep what they receive | Retention rows 21 to 24 |
| TC-16 | **Minors and patients who can't consent:** who consents for them (a guardian), and how that is recorded | Consent texts, privacy notice, terms |
| TC-17 | Keeping a **deactivated doctor's** identity with the records they wrote, with no deletion | ROPA row 1, rights map row 6 |
| TC-18 | Must ILTIAM (or each clinic) **register** with SDAIA's national register or appoint a **data protection officer**? | Privacy notice |
| TC-19 | **Google Play account deletion:** patients don't sign up in the app (a doctor registers them). Is the in-app deletion request enough, or is a web link also required? | Play data safety |
| TC-20 | Is health-related **push text** through Google FCM acceptable, or must pushes be generic ("You have a new update")? | ROPA row 9, finding 1 |
| TC-21 | Where the **feedback dataset** export may be kept, and when it must be deleted after retraining | Retention row 20 |
| TC-22 | What **Redis** (the task queue) holds: ids only, or also personal data | ROPA row 17 |
| TC-23 | Google seeing the phone's IP address through **run-time font downloads**: acceptable, or bundle the fonts | ROPA processors, finding 3 |
| TC-24 | The **governing law, liability and disclaimer** wording of the terms of use | Terms of use |
| TC-25 | **Messages:** the SRS says 12 months (FR-D-13); the backend archives them after 12 months and never deletes them. Is archiving enough? | Retention row 3 |
| TC-26 | When a consent text changes (a new version ID), must every patient consent again, or only when the purpose changes? | Consent texts |
| TC-27 | How long to keep the **in-app notification inbox** (proposed: 12 months) | Retention row 12 |
| TC-28 | How long to keep mail to **`privacy@` and `security@`** (proposed: 12 months after closing) | Retention row 19 |
| TC-29 | The **emergency number** the patient terms name (997) | Terms of use |
| TC-30 | The **right to complain** to SDAIA, and how the notice should say it | Privacy notice |

## What comes next

- The supervisor reviews the legal content and answers the register; a native Arabic speaker reviews the Arabic. Then merge, and #6 closes.
- iltiam/iltiam-web#29 and iltiam/iltiam-mobile#44 show the texts by version ID. iltiam/iltiam-mobile#51 fills the Play form from [play-data-safety.md](play-data-safety.md).
- Backend follow-ups: store the consent version ID; a retention rule for in-app notifications; generic push text if TC-20 says so.
- Runbook 8: the `exports/` lifecycle rule (finding 2). Runbook 6 (#8): backups ([restore-location.md](restore-location.md)).
- Production (#36): turn on `RETENTION_ENFORCE`.
