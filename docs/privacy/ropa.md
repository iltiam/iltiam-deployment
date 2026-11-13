# Record of processing activities (ROPA)

- **Issue:** #6. **Version 1,** approved by the project owner on 2026-11-13 ([decisions](index.md#decisions)).
- **Run by:** the ILTIAM team, for the clinics that use it. Who is the controller is legal review item L1 ([Legal review before public launch](index.md#legal-review-before-public-launch), #23). **Contact:** `privacy@iltiamcare.com`.
- **Checked against:** iltiam-backend `main` (`sha-14223c2`), iltiam-ai-service, iltiam-web and iltiam-mobile `main`, 2026-11-13.

## Where the data lives

Everything we store is in **Oracle Cloud (OCI), Riyadh region (`me-riyadh-1`)** ([ADR-0004](../adr/0004-hosting.md)):

| Place | What | Protection |
|---|---|---|
| **The VM** (one per account, Riyadh) | PostgreSQL: the backend's database and the AI service's database. Redis: the task queue. Container logs | Disks encrypted at rest by OCI. Users reach it only through Cloudflare Tunnels ([Runbook 3](../runbooks/03-cloudflare-tunnels.md)) |
| **Object Storage** (Riyadh) | `iltiam-<SHORT>-wound-images`, `-wound-masks`, `-reports` (reports, and data exports under `exports/`), `-prescriptions`, `-profile-photos`, `-backups` | Private buckets, encrypted with a customer-managed Vault key per environment, short presigned links only ([Runbook 8](../runbooks/08-object-storage.md)) |
| **The phone** (patients and doctors) | The mobile app's offline queue and cache | App storage; tokens in the platform's secure storage |

`<SHORT>` is `staging` or `prod`. Production's backend is not on yet (#36); staging holds test data and the team's own test accounts.

## Data classes

The basis column records the owner's decision on what ILTIAM relies on ([decisions](index.md#decisions)); it is not a legal opinion. Health data is treated as sensitive everywhere.

| # | Data class | Whose | What exactly | Purpose | Basis we rely on | Stored where | Retention |
|---|---|---|---|---|---|---|---|
| 1 | Account identity | everyone | full name, phone number, email (optional), role, clinic, specialty (doctors), preferred language, account status, policies accepted (time and version) | sign-in, contact, roles and permissions | providing the service the clinic gives through ILTIAM; for staff, their work on ILTIAM. A deactivated doctor's name stays with the records they wrote | VM (Postgres) | [retention](retention.md): kept with the account; patients anonymised on a deletion request |
| 2 | Sign-in and security | everyone | password hash, one-time codes (hashed), sessions, trusted devices (browser or app name), authenticator secret (encrypted), failed attempts, lock time, last sign-in IP; sign-in records (`LoginAudit`: phone tried, IP address, user agent, outcome) | protecting accounts, stopping misuse, investigating incidents | security of the service | VM (Postgres) | [retention](retention.md) rows 5 to 8 |
| 3 | Patient profile and medical background | patients | date of birth, gender, medical conditions, allergies, medications, profile photo (stored small, without its metadata), assigned doctor | care by the patient's doctor | providing the service, with the patient's consent | VM (Postgres); photo in `-profile-photos` | kept with the clinical record; anonymised on deletion |
| 4 | Wound photos and masks | patients | wound photos (location metadata such as GPS removed on upload), the AI's segmentation masks, the body location of the wound | wound assessment and follow-up | providing the service, with the patient's consent | `-wound-images`, `-wound-masks` | kept with the clinical record |
| 5 | AI results | patients | wound area and measurements, tissue types, risk level, model version, confidence, progression | supporting the doctor's assessment | explicit consent, `ai-consent-v1` ([consent texts](consent-texts.md)) | VM (Postgres) | kept with the clinical record |
| 6 | Clinical record | patients, written by doctors | doctors' reviews and corrections of AI results, SOAP notes, care plans and acknowledgements, prescriptions (signed, immutable), refill requests, appointments, deterioration alerts | care, continuity, the medical record | providing the service, with the patient's consent | VM (Postgres); prescription and report PDFs in `-prescriptions`, `-reports` | no fixed end; anonymised on deletion |
| 7 | Messages | patients and doctors | message text (encrypted in the database), a link to one of the patient's own visits, sent, delivered and read times | patient to doctor communication | providing the service, with the patient's consent | VM (Postgres) | archived after 12 months, kept with the record |
| 8 | Notifications | everyone | in-app inbox (title and text in Arabic and English, links), delivery log per channel, notification preferences | telling users about results, alerts, reminders, account events | providing the service | VM (Postgres) | delivery logs 12 months; inbox: while the account exists ([retention](retention.md) row 12) |
| 9 | Push tokens | users of the mobile app | Firebase token, platform, app version, last seen | delivering push notifications | providing the service. Push text will hold no health data (iltiam/iltiam-backend#128) | VM (Postgres) | 30 days after the token is revoked |
| 10 | Consent and data-rights records | patients | AI analysis consent and feedback consent (on or off, and when), deletion requests and decisions, data export jobs and export files, the patient's access log | proving consent; handling rights requests | handling the law's duties for consent and rights requests | VM (Postgres); export files in `-reports` under `exports/` | consent and requests: kept; export files 7 days ([retention](retention.md) row 14) |
| 11 | Audit log | everyone | who did what and when, the target record, the IP address, field names changed (never the values) | accountability, security, SRS FR-SA-10 | security of the service | VM (Postgres), append-only | at least 2 years, reviewed yearly |
| 12 | Data on the phone | patients and doctors | photos waiting to upload, cached screens, sign-in tokens | working offline, staying signed in | as rows 1 and 4 | the phone | until uploaded or signed out; removed with the app |
| 13 | AI service jobs | patients | a copy of the photo sent for analysis, the result and the mask | running the AI analysis | as row 5 | VM (the AI service's Postgres) | 24 hours |
| 14 | AI feedback dataset | patients who consented | doctors' corrections with the photo, mask and values, no name, phone or id | improving the AI model | explicit consent, `feedback-consent-v1` | only on the Riyadh VM or in a Riyadh bucket, exported by a Full Super Admin (`manage.py export_feedback_dataset`); never on a laptop or outside OCI Riyadh | deleted when the retraining it was made for is done ([retention](retention.md) row 20) |
| 15 | Breach records | affected users | incident description, who was notified, how, and when | breach notification duty | handling the law's breach duties | VM (Postgres) | kept |
| 16 | Mail to `privacy@` and `security@` | anyone who writes | the email and anything in it | answering requests and security reports | answering the sender's request | the team mailbox, through Cloudflare Email Routing ([Runbook 2](../runbooks/02-cloudflare-dns-tls.md)) | [retention](retention.md) row 19 |
| 17 | Operational data | everyone | container logs (may hold user ids and IP addresses, never codes), the Redis task queue (record ids only, never personal data; task results expire after 1 day), database dumps (pre-deploy dumps on the VM today; scheduled backups when #8 is built) | running and restoring the service | security and continuity of the service | VM (`/srv/iltiam/backups/`); scheduled dumps in `-backups` ([restore-location.md](restore-location.md)) | [retention](retention.md) rows 16 to 18 (object versions, logs, backups) |

## Processors

Each one receives only what is listed. Their contracts and data processing terms are legal review item L3, and transfers outside the Kingdom item L4 ([Legal review before public launch](index.md#legal-review-before-public-launch), #23).

| Processor | Service | What it receives | Where | Notes |
|---|---|---|---|---|
| **Oracle (OCI)** | VM, Postgres disks, Object Storage, Vault, Email Delivery, Monitoring and alarm emails | everything we store (rows 1 to 17); emails we send (address, codes, invitation and reset links, breach notices) | Riyadh | Email Delivery processes mail in Riyadh (ADR-0004, Decision 6). Alarm emails hold no personal data |
| **Cloudflare** | DNS, TLS at its edge, Tunnels; Email Routing for `privacy@` and `security@` | every request and answer between the apps and our servers, decrypted at Cloudflare's edge, so it sees health data in transit; mail sent to our addresses | its global network, possibly **outside the Kingdom** (L4) | Keeping decryption in the Kingdom needs the paid Data Localization Suite (ADR-0004, Decision 4). We export no Cloudflare logs |
| **Authentica** | SMS codes ([Runbook 12](../runbooks/12-authentica.md)); WhatsApp codes later (#61) | phone number, the code, the template ID (language) | Saudi provider | Its portal's SMS log shows the messages; how long it keeps them is L3. With a sender name later, SMS copies of alerts would also go through it |
| **Google (Firebase Cloud Messaging)** | push notifications to Android ([Runbook 11](../runbooks/11-firebase.md)) | the device token, each notification's title, text and link | **outside the Kingdom** (L4) | Analytics is off. Push text can mention a wound result today; it will hold no health data (iltiam/iltiam-backend#128) |
| **Google (mailbox)** | the team mailbox that receives `privacy@` and `security@` | those emails | **outside the Kingdom** (L4) | ADR-0004, Decision 6 |
| **Google (Fonts)** | fonts for the mobile app, downloaded at run time | the phone's IP address and app identity | **outside the Kingdom** (L4) | Until the app bundles its fonts (iltiam/iltiam-mobile#77); then this row is removed |
| **Uptime monitoring** | **none yet** | nothing | | When #10 adds a pinger, it calls `/api/health/` only and receives no personal data; add it here first |

**Not processors of user data:** GitHub (code, CI and images only; never user data, dumps or restores, see [restore-location.md](restore-location.md)), Google Play (distributes the app; the [data safety](play-data-safety.md) form describes it).

## What we never do

- Sell data, or use it for advertising.
- Send photos, measurements or notes to anyone but the patient, their care team and the processors above.
- Use a patient's data to train the AI without their feedback consent (`feedback-consent-v1`).
- Keep codes in logs: the backend logs no code since Authentica is on (Runbook 12, section 9, check 9).

## Keeping this record current

Update this page in the same PR as any change that adds a data class, a field with personal data, a processor, or a storage place. Review it before production (#36) and then yearly with the key rotation (Runbook 8, section 15).
