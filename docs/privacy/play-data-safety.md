# Google Play data safety answers

- **Status:** final answers, approved by the project owner on 2026-11-13. **Used by:** iltiam/iltiam-mobile#51 and the store checklist #68, in **Play Console → App content → Data safety.**
- **App:** the ILTIAM Android app (patients and doctors). Checked against iltiam-mobile `main` on 2026-11-13: its libraries and Android permissions.
- **These answers describe the app as it will be submitted**, after the blockers below are done. Re-check this page if the app adds a library, a permission or a data type. Google's question wording changes; if a question doesn't match the console, answer from the [ROPA](ropa.md).

## Before entering these answers

These must be done first, or the answers below would be wrong:

- [ ] iltiam/iltiam-mobile#77: fonts bundled, so the app sends nothing to Google Fonts.
- [ ] iltiam/iltiam-mobile#76: the unused `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO` permissions removed.
- [ ] iltiam/iltiam-web#70: `https://iltiamcare.com/privacy` and `https://iltiamcare.com/delete-account` are live and tested. **Until then they are planned URLs.**

## What the app contains

- **No analytics, crash reporting or advertising SDK.** Firebase is used for push messages only; Analytics is off ([Runbook 11](../runbooks/11-firebase.md)).
- **Data leaves the phone only to:** our own API (through Cloudflare to the servers in Riyadh), and Firebase Cloud Messaging (the push token).
- **Permissions after #76:** internet, camera, notifications, biometrics (local unlock; the fingerprint never leaves the phone), photos.

## Data collection and security

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | see the table below |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | HTTPS only |
| Which account creation methods does your app support? | **Username and password** (the console's closest option) | the clinic creates the account; the user sets a password with an SMS code. No sign-up in the app |
| Do you provide a way for users to request that their data is deleted? | **Yes** | in the app: Profile → Privacy → Delete my data ([rights map](rights-map.md#6-destruction-deletion-done-as-anonymisation)); without the app: the web link below or `privacy@iltiamcare.com` |
| Delete account URL | **`https://iltiamcare.com/delete-account`** (planned, iltiam/iltiam-web#70) | explains the request and what is kept (the medical record without identity), and offers a way to ask without the app |
| Has your app been independently validated against a global security standard? | **No** | |
| Is your app's data shared with third parties? | **No**, for every type below | Oracle, Cloudflare, Authentica and Google act as our service providers ([ROPA](ropa.md#processors)), which Play doesn't count as sharing |
| Privacy policy URL | **`https://iltiamcare.com/privacy`** (planned, iltiam/iltiam-web#70) | `privacy-notice-v1` |

## Data types

"Collected" means it leaves the phone. Purposes use Play's names. None is used for analytics, advertising or personalisation.

| Play category | Data type | Collected | Required or optional | Purposes | What it is |
|---|---|---|---|---|---|
| Personal info | Name | yes | required | App functionality, Account management | the user's name |
| Personal info | Email address | yes | optional | App functionality, Account management | for codes and notices, if given |
| Personal info | User IDs | yes | required | App functionality, Account management | the account id |
| Personal info | Phone number | yes | required | App functionality, Account management, Fraud prevention, security and compliance | sign-in and codes |
| Personal info | Other info | yes | required | App functionality | date of birth, gender (patients) |
| Health and fitness | Health info | yes | required | App functionality | medical background, wound measurements, notes, care plans, prescriptions |
| Messages | Other in-app messages | yes | optional | App functionality | messages with the care team |
| Photos and videos | Photos | yes | required (patients) | App functionality | wound photos, profile photo. Location data is removed |
| Device or other IDs | Device or other IDs | yes | required for notifications | App functionality | the Firebase push token |
| App info and performance | Crash logs, Diagnostics | **no** | | | no crash or diagnostics SDK |
| App activity | App interactions, other actions | **no** | | | the server's audit log records actions, but the app sends no activity tracking |
| Location | Approximate, Precise | **no** | | | GPS is removed from photos; no location permission |
| Financial info, Contacts, Calendar, Audio, Files and docs, Web browsing | | **no** | | | |

**Ephemeral processing:** **No** for every type: data is stored, not only processed in memory.

## Other Play Console forms

The **Health apps declaration**, target audience (adults; patients under 18 only through a parent or guardian, per `terms-v1`) and the rest are in the store publishing checklist, #68.
