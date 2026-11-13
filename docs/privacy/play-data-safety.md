# Google Play data safety answers

- **Issue:** #6. **Used by:** iltiam/iltiam-mobile#51, in **Play Console → App content → Data safety.**
- **App:** the ILTIAM Android app (patients and doctors). Checked against iltiam-mobile `main` on 2026-11-13: its libraries and Android permissions.
- **Draft:** needs review before it is entered. Google's question wording changes; if a question below doesn't match the console, answer from the [ROPA](ropa.md).

## What the app contains

- **No analytics, crash reporting or advertising SDK.** Firebase is used for push messages only; Analytics is off ([Runbook 11](../runbooks/11-firebase.md)).
- **Libraries that send data off the phone:** our own API (through Cloudflare to the VM in Riyadh), Firebase Cloud Messaging (the push token), and `google_fonts`, which downloads the app's fonts from Google the first time (**TO CONFIRM, TC-23**; bundling the fonts removes it).
- **Permissions:** internet, camera, notifications, biometrics (local unlock; the fingerprint never leaves the phone), photos. The manifest also asks for `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO`, which the app doesn't use. **Mobile follow-up (iltiam/iltiam-mobile#76):** remove them before release, or Play may ask why.

## Data collection and security

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | see the table below |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | HTTPS only, through Cloudflare |
| Which account creation methods does your app support? | **The clinic creates the account; the user sets a password with an SMS code.** Choose the console's closest option (username and password) | no sign-up in the app |
| Do you provide a way for users to request that their data is deleted? | **Yes** | in the app: Profile → Privacy → Delete my data ([rights map](rights-map.md#6-destruction-deletion-done-as-anonymisation)). The record is anonymised; medical records are kept. Whether a web link is also required: **TO CONFIRM (TC-19)** |
| Delete account URL | **TO CONFIRM (TC-19).** Suggested: a page on `iltiamcare.com` explaining the in-app request and `privacy@iltiamcare.com` | Play asks for one when an app has accounts |
| Has your app been independently validated against a global security standard? | **No** | |
| Is your app's data shared with third parties? | **No** for every type below | Oracle, Cloudflare, Authentica and Google act as our service providers ([ROPA](ropa.md#processors)), which Play doesn't count as sharing. **TO CONFIRM (TC-14)** that each acts only on our instructions |

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
| App info and performance | Crash logs, Diagnostics | **no** | | | no crash or diagnostics SDK |
| App activity | App interactions, other actions | **no** | | | the server's audit log records actions, but the app sends no activity tracking |
| Device or other IDs | Device or other IDs | yes | required for notifications | App functionality | the Firebase push token |
| Location | Approximate, Precise | **no** | | | GPS is removed from photos; no location permission |
| Financial info, Contacts, Calendar, Audio, Files and docs, Web browsing | | **no** | | | |

**Ephemeral processing:** answer **No** for every type: data is stored, not only processed in memory.

## Before submitting

- [ ] The supervisor confirms TC-14, TC-19 and TC-23.
- [ ] The mobile app drops `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO` (iltiam/iltiam-mobile#76) (or this page explains them).
- [ ] The privacy policy URL in Play Console points to the published `privacy-notice-v1`.
- [ ] Re-check this page when the app adds a library, a permission or a data type.
