# PDPL documents

> **Version 1 - approved by the project owner.**
>
> This is approved documentation text. It is **not** a verified PDPL compliance assessment, a regulatory approval or a clinical validation, and it doesn't make ILTIAM ready for real patients. The open legal points and the public-launch blockers are listed below and tracked in #23.

- **Issue:** iltiam/iltiam-deployment#6 (closed when version 1 was merged: the documentation task is done). **SRS:** FR-P-7.1, NFR-SEC-04, FR-SA-10.
- **Version 1:** approved by the project owner on 2026-11-13.
- **Law:** the Saudi Personal Data Protection Law (PDPL) and its Implementing Regulations. These documents cite no article numbers and make no legal conclusions: they describe what ILTIAM does, and the owner's decisions.

> **This repository is public.** These pages hold no namespace, OCID, key, real phone number or personal data. Bucket names and the public domain `iltiamcare.com` are already public in the runbooks.

## The documents

| Document | What it holds |
|---|---|
| [Record of processing (ROPA)](ropa.md) | Each data class: what, whose, why, the basis we rely on, where it is stored, who processes it, how long it's kept |
| [Retention schedule](retention.md) | How long each data class is kept, and the job or manual process that enforces it |
| [Rights map](rights-map.md) | Each PDPL right → app screen → backend endpoint → backend test |
| [Consent texts](consent-texts.md) | The AI analysis and feedback dataset consents, Arabic and English, with version IDs |
| [Privacy notice](privacy-notice.md) | For patients and staff, Arabic and English, `privacy-notice-v1`: final, for the stores |
| [Terms of use](terms-of-use.md) | Patient terms (`terms-v1`) and staff policies (`staff-policies-v1`), Arabic and English: final, for the stores |
| [Play data safety](play-data-safety.md) | The final answers for Google Play Console's Data safety form |
| [Backups and restores stay in Riyadh](restore-location.md) | The record that dumps and restore tests never leave the Riyadh VM and buckets |

## Decisions

All made by the project owner. "Safest simple choice" means the option that sends the least data, keeps it the shortest time that the service allows, or adds no new promise the code doesn't keep.

| Date | Decision |
|---|---|
| 2026-11-09 | The backend's retention schedule (iltiam-backend `docs/retention.md`, PR #108) is adopted as the base of [retention.md](retention.md) |
| 2026-11-13 | **Version 1 is final** for the privacy notice, the terms and the Play answers, because the stores need them. `privacy-notice-v1` and `terms-v1` are published at `https://iltiamcare.com/privacy` and `/terms` (planned until iltiam/iltiam-web#70 is live and tested) |
| 2026-11-13 | **#6 closes when version 1 is merged.** Showing the texts in the apps is tracked in iltiam/iltiam-web#29 (web) and iltiam/iltiam-mobile#44 (Android); the stores in #68 |
| 2026-11-13 | Each user-facing text has a version ID (`ai-consent-v1`, `feedback-consent-v1`, `privacy-notice-v1`, `terms-v1`, `staff-policies-v1`). A changed text gets a new ID, and **patients are asked again for every new consent version** |
| 2026-11-13 | **Basis we rely on:** we process health data only to provide the service the clinic gives through ILTIAM, and with the patient's consent; AI analysis and the AI feedback dataset need their own explicit consent. Staff data: their work on ILTIAM. Breach and rights records: handling the law's duties |
| 2026-11-13 | **Health data is treated as sensitive** everywhere in ILTIAM |
| 2026-11-13 | **Doctor accounts are never deleted, only deactivated,** and their name stays on the records they wrote (medical data integrity) |
| 2026-11-13 | **Clinical records** are kept with no fixed end; a patient's deletion request removes their identity. **Messages** are archived after 12 months and kept with the record. **Audit and sign-in records** are kept at least 2 years, reviewed yearly |
| 2026-11-13 | **In-app notifications** are kept while the account exists and deleted when the patient is anonymised (what the backend does today) |
| 2026-11-13 | **Mail to `privacy@` and `security@`:** deleted 12 months after the request or report is closed, by hand each month |
| 2026-11-13 | **Redis** (the task queue) holds record ids only, never personal data; task results expire after 1 day |
| 2026-11-13 | **Google Fonts:** the mobile app will bundle its fonts (iltiam/iltiam-mobile#77). Until then the privacy notice says that Google may see the device's internet address |
| 2026-11-13 | **Uptime monitoring:** none yet. When #10 adds one, it calls `/api/health/` only, receives no personal data, and is added to the ROPA first |
| 2026-11-13 | **AI feedback dataset:** exported only to the Riyadh VM or a Riyadh bucket, never to a laptop or outside OCI Riyadh, and deleted when the retraining it was made for is done |
| 2026-11-13 | **Push text** will hold no health data (iltiam/iltiam-backend#128) |
| 2026-11-13 | **Patients under 18** use ILTIAM only through a parent or legal guardian, who accepts the notice and terms for them |
| 2026-11-13 | **Rights requests** are answered within 30 days; breaches are notified to affected users and the competent authority as the law requires; users can complain to SDAIA |
| until after the demo | `RETENTION_ENFORCE` stays off on staging: the retention job only counts. Production turns it on before launch (#66, #36) |

## Legal review before public launch

These need a legal answer that the project owner can't give alone. **They block the public launch** and are tracked in #23. The documents above don't depend on the answers, but an answer may require a new version of a text.

| # | Question | Affects |
|---|---|---|
| L1 | **Controller per clinic:** is each clinic the controller of its patients' data, with ILTIAM as its processor, or is ILTIAM a controller too? What agreement does each clinic sign? | privacy notice section 1, terms, clinic onboarding |
| L2 | **SDAIA registration and data protection officer:** must ILTIAM (or each clinic) register with SDAIA's national register or appoint a DPO? | privacy notice section 11 |
| L3 | **Processor contracts:** data processing terms with Oracle, Cloudflare, Authentica and Google, and how long each keeps what it receives (its own logs) | [ROPA processors](ropa.md#processors), [retention](retention.md) rows 21 to 24 |
| L4 | **Transfers outside the Kingdom:** Cloudflare (TLS ends at its edge; Email Routing), Google (FCM, the team mailbox, fonts until #77). Which transfer rules apply, and whether Cloudflare's paid Data Localization Suite is needed | privacy notice section 5, [ROPA](ropa.md) |

## Public-launch blockers

Besides L1 to L4, these must be done before real patients or a store submission (#68):

| Blocker | Issue |
|---|---|
| Anonymisation keeps wound photos, notes and message text: deletion must do exactly what the privacy notice says | iltiam/iltiam-backend#129 |
| Push text without health data | iltiam/iltiam-backend#128 |
| Public `/privacy`, `/terms` and `/delete-account` pages, with a way to ask for deletion without the app | iltiam/iltiam-web#70 |
| The apps show the texts and record acceptance | iltiam/iltiam-web#29, iltiam/iltiam-mobile#44 |
| Fonts bundled; unused media permissions removed | iltiam/iltiam-mobile#77, iltiam/iltiam-mobile#76 |
| Retention enforced in production; export files cleaned up after 7 days | #66, #36, #65 |
| The consent version stored with each consent | iltiam/iltiam-backend#130 |
| Super Admin screens for deletion requests and breaches (or a documented API procedure) | iltiam/iltiam-web#69 |

## Findings while writing

Facts found in the code on 2026-11-13, each with its issue:

1. **Push text through Google** can mention a wound result, for example "The result of your latest wound photo shows a high risk" (iltiam-backend `apps/notifications/catalog.py`): iltiam/iltiam-backend#128.
2. **Export files** under `exports/` in `iltiam-<SHORT>-reports` are not removed by a bucket rule yet; [retention.md](retention.md) row 14 names a monthly manual clean-up until #65.
3. **The mobile app downloads its fonts from Google at run time:** iltiam/iltiam-mobile#77.
4. **The backend records when a consent changed, not which text version:** iltiam/iltiam-backend#130.
5. **Anonymisation keeps wound photos, notes and message text:** iltiam/iltiam-backend#129.
6. **No Super Admin web screens** for deletion requests and breach incidents: iltiam/iltiam-web#69.
7. **`RETENTION_ENFORCE` isn't passed by the deploy:** #66.
8. **Unused Android media permissions:** iltiam/iltiam-mobile#76.
9. **Only "AI result viewed" is logged as a view.** Other reads of a record aren't logged, so the texts promise only what is logged: changes, and doctors' views of AI results.
