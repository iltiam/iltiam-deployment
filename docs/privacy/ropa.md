# Record of processing activities (ROPA)

- **Issue:** #6. **Version:** draft of 2026-11-13, **needs review** (see the [TO CONFIRM register](index.md#to-confirm-register)).
- **Controller:** **TO CONFIRM (TC-1).** **Contact:** `privacy@iltiamcare.com`.
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

The legal basis column is a proposal. **Every legal basis is TO CONFIRM.** Health data is treated as sensitive data (**TO CONFIRM, TC-6**).

| # | Data class | Whose | What exactly | Purpose | Legal basis | Stored where | Retention |
|---|---|---|---|---|---|---|---|
| 1 | Account identity | everyone | full name, phone number, email (optional), role, clinic, specialty (doctors), preferred language, account status, policies accepted (time and version) | sign-in, contact, roles and permissions | performing the service the user or clinic asked for; for staff, their work relationship. **TO CONFIRM (TC-2, TC-5).** A deactivated doctor's identity stays with the records they wrote (**TO CONFIRM, TC-17**) | VM (Postgres) | [retention](retention.md): kept with the account; patients anonymised on a deletion request |
| 2 | Sign-in and security | everyone | password hash, one-time codes (hashed), sessions, trusted devices (browser or app name), authenticator secret (encrypted), failed attempts, lock time, last sign-in IP; sign-in records (`LoginAudit`: phone tried, IP address, user agent, outcome) | protecting accounts, stopping misuse, investigating incidents | security of the service. **TO CONFIRM (TC-5)** | VM (Postgres) | [retention](retention.md) rows 5 to 8 |
| 3 | Patient profile and medical background | patients | date of birth, gender, medical conditions, allergies, medications, profile photo (stored small, without its metadata), assigned doctor | care by the patient's doctor | **TO CONFIRM (TC-2)** | VM (Postgres); photo in `-profile-photos` | kept with the clinical record; anonymised on deletion |
| 4 | Wound photos and masks | patients | wound photos (location metadata such as GPS removed on upload), the AI's segmentation masks, the body location of the wound | wound assessment and follow-up | **TO CONFIRM (TC-2)** | `-wound-images`, `-wound-masks` | kept with the clinical record (TC-9) |
| 5 | AI results | patients | wound area and measurements, tissue types, risk level, model version, confidence, progression | supporting the doctor's assessment | explicit consent, `ai-consent-v1` ([consent texts](consent-texts.md)). **TO CONFIRM (TC-3)** | VM (Postgres) | kept with the clinical record |
| 6 | Clinical record | patients, written by doctors | doctors' reviews and corrections of AI results, SOAP notes, care plans and acknowledgements, prescriptions (signed, immutable), refill requests, appointments, deterioration alerts | care, continuity, the medical record | **TO CONFIRM (TC-2)** | VM (Postgres); prescription and report PDFs in `-prescriptions`, `-reports` | permanent (TC-9); anonymised on deletion |
| 7 | Messages | patients and doctors | message text (encrypted in the database), a link to one of the patient's own visits, sent, delivered and read times | patient to doctor communication | **TO CONFIRM (TC-2)** | VM (Postgres) | archived after 12 months (TC-25) |
| 8 | Notifications | everyone | in-app inbox (title and text in Arabic and English, links), delivery log per channel, notification preferences | telling users about results, alerts, reminders, account events | **TO CONFIRM (TC-2, TC-5)** | VM (Postgres) | delivery logs 12 months; inbox: [retention](retention.md) row 12 |
| 9 | Push tokens | users of the mobile app | Firebase token, platform, app version, last seen | delivering push notifications | **TO CONFIRM (TC-2)**. Push text can be health-related (**TO CONFIRM, TC-20**; iltiam/iltiam-backend#128) | VM (Postgres) | 30 days after the token is revoked |
| 10 | Consent and data-rights records | patients | AI analysis consent and feedback consent (on or off, and when), deletion requests and decisions, data export jobs and export files, the patient's access log | proving consent; handling rights requests | legal obligation to handle rights requests. **TO CONFIRM (TC-5)** | VM (Postgres); export files in `-reports` under `exports/` | consent and requests: kept; export files 7 days ([retention](retention.md) row 14) |
| 11 | Audit log | everyone | who did what and when, the target record, the IP address, field names changed (never the values) | accountability, security, SRS FR-SA-10 | **TO CONFIRM (TC-5)** | VM (Postgres), append-only | at least 2 years (TC-10) |
| 12 | Data on the phone | patients and doctors | photos waiting to upload, cached screens, sign-in tokens | working offline, staying signed in | as rows 1 and 4 | the phone | until uploaded or signed out; removed with the app |
| 13 | AI service jobs | patients | a copy of the photo sent for analysis, the result and the mask | running the AI analysis | as row 5 | VM (the AI service's Postgres) | 24 hours |
| 14 | AI feedback dataset | patients who consented | doctors' corrections with the photo, mask and values, no name, phone or id | improving the AI model | explicit consent, `feedback-consent-v1`. **TO CONFIRM (TC-4)** | a folder chosen by the Super Admin who exports it (`manage.py export_feedback_dataset`). **TO CONFIRM (TC-21)** | **TO CONFIRM (TC-21)** |
| 15 | Breach records | affected users | incident description, who was notified, how, and when | breach notification duty | legal obligation. **TO CONFIRM (TC-7)** | VM (Postgres) | kept |
| 16 | Mail to `privacy@` and `security@` | anyone who writes | the email and anything in it | answering requests and security reports | answering the sender's request. **TO CONFIRM (TC-5)** | the team mailbox, through Cloudflare Email Routing ([Runbook 2](../runbooks/02-cloudflare-dns-tls.md)) | [retention](retention.md) row 19 |
| 17 | Operational data | everyone | container logs (may hold user ids and IP addresses, never codes), the Redis task queue (**TO CONFIRM, TC-22**), database dumps (pre-deploy dumps on the VM today; scheduled backups when #8 is built) | running and restoring the service | security and continuity of the service. **TO CONFIRM (TC-5)** | VM (`/srv/iltiam/backups/`); scheduled dumps in `-backups` ([restore-location.md](restore-location.md)) | [retention](retention.md) rows 16 to 18 (object versions, logs, backups) |

## Processors

Each one receives only what is listed. **Contracts and data processing terms: TO CONFIRM (TC-14).**

| Processor | Service | What it receives | Where | Notes |
|---|---|---|---|---|
| **Oracle (OCI)** | VM, Postgres disks, Object Storage, Vault, Email Delivery, Monitoring and alarm emails | everything we store (rows 1 to 17); emails we send (address, codes, invitation and reset links, breach notices) | Riyadh | Email Delivery processes mail in Riyadh (ADR-0004, Decision 6). Alarm emails hold no personal data |
| **Cloudflare** | DNS, TLS at its edge, Tunnels; Email Routing for `privacy@` and `security@` | every request and answer between the apps and our servers, decrypted at Cloudflare's edge, so it sees health data in transit; mail sent to our addresses | its global network, possibly **outside the Kingdom** (**TO CONFIRM, TC-8**) | Keeping decryption in the Kingdom needs the paid Data Localization Suite (ADR-0004, Decision 4). We export no Cloudflare logs |
| **Authentica** | SMS codes ([Runbook 12](../runbooks/12-authentica.md)); WhatsApp codes later (#61) | phone number, the code, the template ID (language) | Saudi provider | Its portal's SMS log shows the messages (**TO CONFIRM, TC-15**). With a sender name later, SMS copies of alerts would also go through it |
| **Google (Firebase Cloud Messaging)** | push notifications to Android ([Runbook 11](../runbooks/11-firebase.md)) | the device token, each notification's title, text and link | **outside the Kingdom** (**TO CONFIRM, TC-8**) | Analytics is off. Push text can mention a wound result (**TO CONFIRM, TC-20**; iltiam/iltiam-backend#128) |
| **Google (mailbox)** | the team mailbox that receives `privacy@` and `security@` | those emails | **outside the Kingdom** (**TO CONFIRM, TC-8**) | ADR-0004, Decision 6 |
| **Google (Fonts)** | fonts for the mobile app, downloaded at run time | the phone's IP address and app identity | **outside the Kingdom** | **TO CONFIRM (TC-23)**: bundling the fonts removes it |
| **Uptime pinger** | checks that the sites answer (ADR-0004: "a hosted pinger") | **TO CONFIRM (TC-13):** the service isn't chosen; it must call `/api/health/` only and receive no personal data | **TO CONFIRM (TC-13)** | |

**Not processors of user data:** GitHub (code, CI and images only; never user data, dumps or restores, see [restore-location.md](restore-location.md)), Google Play (distributes the app; the [data safety](play-data-safety.md) form describes it).

## What we never do

- Sell data, or use it for advertising.
- Send photos, measurements or notes to anyone but the patient, their care team and the processors above.
- Use a patient's data to train the AI without their feedback consent (`feedback-consent-v1`).
- Keep codes in logs: the backend logs no code since Authentica is on (Runbook 12, section 9, check 9).

## Keeping this record current

Update this page in the same PR as any change that adds a data class, a field with personal data, a processor, or a storage place. Review it before production (#36) and then yearly with the key rotation (Runbook 8, section 15).
