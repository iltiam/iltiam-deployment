# Runbook: personal data breach, notify within 72 hours

Step by step, from "this is a breach" to "everyone who must know has been told, and we can prove it". Issue #21
(DEP-09); SRS FR-P-7.1 (patients told within 72 hours); the backend's breach incidents and notices
(iltiam-backend#85, `apps/notifications/breach.py`). Start here only after the
[incident response plan](incident-response.md), section 4, says "breach" (or "we don't know yet").

> Rehearsed end to end on the local stack on 2026-11-21: [tabletop record](tabletop-2026-11-21.md). The commands below
> are the ones that worked there.

## 0. The clock

| Hour | What must be done |
|---|---|
| 0 | Discovery: the time the team became aware. Write it down to the minute |
| 0 to 4 | Contain (incident plan, section 8), preserve evidence (section 7 there), first scope |
| 4 to 24 | Decide: is it notifiable, who is affected, what to say (sections 1 to 3 below) |
| 24 to 48 | Record the incident in the backend and notify patients (sections 4 and 5); notify the clinics |
| before 72 | Notify SDAIA when required (section 6); record everything (section 7) |

Do not wait for a complete investigation to notify. If more patients turn out to be affected later, record a second
incident with the new scope: notifying again only reaches patients not yet told.

## 1. Decide what happened

Write in the incident record, in plain words:

1. **What data:** categories only (for example "wound photos and visit notes", "names and phone numbers"). Never a
   patient's actual data.
2. **Whose:** every patient, one clinic's patients, or a list. Get the list from the audit log or the database on the
   VM (never copy it off the VM; work in a Riyadh backup if needed).
3. **When it happened** (`occurred_on`, a date) and **when we found out** (`discovered_at`, a time).
4. **The risk to patients:** what could someone do with it (identity theft, embarrassment, health information known
   to others).
5. **What we already did:** containment, rotation, fix.

## 2. Decide who must be told

| Who | When | How |
|---|---|---|
| **Affected patients** | Always for a confirmed breach of their data, **within 72 hours of discovery** (FR-P-7.1). The law asks for notice without undue delay when the breach may harm them; we hold ourselves to 72 hours in every case | The backend's breach notice (section 5): SMS and in-app always, email when the patient has an address |
| **The clinics** whose patients are affected | Same day as the patients, before if possible | The incident lead calls the clinic's contact, then emails from `privacy@` |
| **SDAIA** (Saudi Data and AI Authority) | Within 72 hours of discovery, when the breach may harm the people affected (PDPL Implementing Regulations) | SDAIA's national data governance platform, by the controller (section 6) |
| Processors involved (Oracle, Cloudflare, Authentica, Google) | When the breach is on their side or they must act | Their security contact or support case |

Who is the **controller** (each clinic, or ILTIAM, or both) and who registers with SDAIA are legal items L1 and L2
([privacy overview](../privacy/index.md#legal-review-before-public-launch), tracked in #23). Until they are decided,
the incident lead notifies SDAIA on ILTIAM's behalf and tells each clinic so it can notify as its own controller.

## 3. Write the patient text

Two short descriptions of the affected data, one Arabic, one English, each one line. They go inside a fixed text the
backend already has (email and SMS): "we confirmed a security incident on *date* that may have affected your data
(*description*). We will never ask for your code or password. Questions: *contact*."

- Data categories only; no clinical detail, no names, no numbers. The SMS can show on a lock screen.
- Same meaning in both languages; read the Arabic aloud once.
- Contact: `privacy@iltiamcare.com`.

## 4. Record the incident in the backend

Today this is done through the API by a **Full Super Admin** (the web screens are iltiam/iltiam-web#69). Do it from a
computer you control, against `https://api.iltiamcare.com` (staging: `https://staging-api.iltiamcare.com`).

1. Get an access token: sign in as the Super Admin in the web portal, or with the two sign-in calls
   (`POST /api/auth/login/`, then `/api/auth/login/verify/`). Keep the token in your shell only:
   `export TOKEN=...` (it expires with the 15-minute session).
2. **Write the incident as a UTF-8 file**, never as text on the command line. On Windows, Arabic typed into a
   command-line argument arrives as `?????` (finding F1 of the rehearsal). Save `incident.json` in an editor as UTF-8:

    ```json
    {
      "reference": "INC-2026-001",
      "description_ar": "صور الجروح وملاحظات الزيارات",
      "description_en": "wound photos and visit notes",
      "occurred_on": "2026-11-20",
      "discovered_at": "2026-11-21T09:30:00+03:00",
      "contact": "privacy@iltiamcare.com",
      "scope": "CLINIC",
      "clinic_id": "<the clinic's id>"
    }
    ```

    `scope` is `ALL` (every patient), `CLINIC` (with `clinic_id`) or `PATIENTS` (with `patient_ids`, a list of patient
    ids). `discovered_at` cannot be in the future; `occurred_on` cannot be after it.

3. Create it:

    ```bash
    curl -s -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json; charset=utf-8' \
      --data-binary @incident.json https://api.iltiamcare.com/api/breach-incidents/
    ```

    The answer has the incident's `id` and its `deadline` (discovery + 72 h).

4. **Check it before notifying.** A recorded incident cannot be edited (finding F2): read it back and compare every
   word, especially the Arabic.

    ```bash
    curl -s -H "Authorization: Bearer $TOKEN" https://api.iltiamcare.com/api/breach-incidents/<id>/
    ```

    If anything is wrong, do not notify: create a new incident with a new reference (for example `INC-2026-001b`) and
    note in the record that the first one was not used.

## 5. Notify the patients

1. Notify (the incident lead says "go" in the record first):

    ```bash
    curl -s -X POST -H "Authorization: Bearer $TOKEN" https://api.iltiamcare.com/api/breach-incidents/<id>/notify/
    ```

    The answer counts `notified`, `not_delivered` and `already_notified`. Each patient gets the SMS and the in-app
    notice in their language, and the email when they have an address. The backend audits one entry per patient.

2. If `not_delivered` is above 0, run the same call again later: it only reaches patients not yet notified. If it
   stays above 0, call those patients through their clinic.
3. Export the proof:

    ```bash
    curl -s -H "Authorization: Bearer $TOKEN" -o notices-INC-2026-001.csv \
      https://api.iltiamcare.com/api/breach-incidents/<id>/notices/export/
    ```

    The CSV lists each notice with the time and each channel's result (`SENT`, `FAILED`, `SKIPPED` for no email). It
    is personal data: keep it in the private incident folder only, in the Kingdom.

Alternative without the API (on the VM, same sending code): `manage.py send_breach_notice --incident ... --admin ...
--occurred-on ... --what-ar ... --what-en ... --contact ... (--patient ... | --all-patients) [--dry-run]` through
`scripts/compose.sh production exec backend-web python manage.py ...`. Run `--dry-run` first. It records audit
entries but no incident row, so prefer the API.

## 6. Notify SDAIA

When section 2 says so, before the 72 hours end, on SDAIA's national data governance platform. Have ready:

- Who we are and the contact person (the incident lead, `privacy@iltiamcare.com`).
- What happened, when it happened, when we found out.
- Data categories and the approximate number of people and records affected.
- Likely consequences for them.
- What we did to contain it and to prevent it again, and that patients were notified (date, channels).

Put SDAIA's reference number in the incident record. If information is still missing at 72 hours, notify with what
is known and send the rest as a follow-up.

## 7. Record and close

- Incident record (incident plan, section 6): decision, timeline, notices CSV location and SHA-256, SDAIA reference,
  clinics told and when.
- The backend keeps the incident and one notice per patient; patients see the notice in the app.
- Within 2 weeks: the review (incident plan, phase 7), findings filed as issues without sensitive details.

## 8. If it fails

| Symptom | Fix |
|---|---|
| 403 on `/api/breach-incidents/` | Not a Full Super Admin, or the session expired (15 min): sign in again |
| 400 on `discovered_at` or `occurred_on` | Discovery in the future, or the date after discovery: fix the file |
| 400 "an incident with this reference exists" | References are unique, even for incidents not used: choose a new one |
| Arabic shows `?????` in the answer | The text did not go as UTF-8: use the file and `--data-binary @incident.json` (section 4) |
| `not_delivered` stays above 0 | SMS provider down or numbers wrong: check Authentica; the in-app notice still reached them; call through the clinic |
| 429 on notify or export | Throttled (one fan-out at a time); wait a minute |
