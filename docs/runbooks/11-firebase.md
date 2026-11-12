# Runbook 11: Firebase project for FCM push on Android (service account and app configs)

- **Issue:** iltiam/iltiam-deployment#14 (DEP-13). **Decision record:** [ADR-0004](../adr/0004-hosting.md): Firebase is used for push only, never for phone sign-in (that is Authentica, [Runbook 12](12-authentica.md)). **Backend side:** iltiam-backend#73 (done). **App side:** iltiam-mobile#23 (flavors, done) and #31 (push in the app, open).
- **Who:** ben-fatah, who owns the Firebase project, with admin rights on `iltiam/iltiam-deployment` and `iltiam/iltiam-mobile`, and SSH to the VM for one check. No cloud experience needed; follow the steps in order.
- **Time:** about 45 minutes for sections 4 to 9. The test push (section 10) needs a staging build of the app, so allow another 30 minutes.
- **Result:**
  - a Firebase project `iltiam`, with Google Analytics off;
  - one Android app in it per flavor: dev, staging and prod;
  - each app's `google-services.json` in the iltiam-mobile repository's secrets, and never in git;
  - the backend's service-account key in the staging GitHub Environment, and nowhere else;
  - push turned on in staging, and a test push that reaches a real Android phone.

> **This repository is public. Never paste a secret into this runbook, an issue, a PR, a commit or a chat.** That includes the service-account key file and anything in it (the private key, the client email, the key ID), the project **number**, the app IDs and API key in `google-services.json`, any FCM registration token (it names one phone), and full phone numbers. Use the placeholders below. When you record a test, give the phone model and Android version, never a token.

| Placeholder | Meaning |
|---|---|
| `<ENV>` | `staging` or `production`: the GitHub Environment |
| `<KEY_FILE>` | The service-account key file Firebase downloads, `iltiam-…-firebase-adminsdk-….json` |
| `<STAGING_FILE>`, `<DEV_FILE>`, `<PROD_FILE>` | The three `google-services.json` files, renamed after download so they don't get mixed up (section 5) |
| `<YOUR_GOOGLE_ACCOUNT>` | The Google account that owns the project (ben-fatah's) |

The Firebase console changes its menus from time to time. The names below are from the console as of November 2026. If a menu isn't where this says, look for its name on the page. Steps marked **(check on screen)** weren't confirmed click by click.

## As built

Filled in when the steps are done. Names and dates only: never a key, a project number, an app ID or a token.

| Item | Value |
|---|---|
| Firebase project (section 4) | |
| Second owner (section 4, step 6) | |
| Android apps: dev, staging, prod (section 5) | |
| `GOOGLE_SERVICES_JSON_DEV`, `_STAGING`, `_PROD` in iltiam-mobile (section 6) | |
| Cloud Messaging API (V1) (section 7) | |
| `FCM_SERVICE_ACCOUNT_JSON` in the staging Environment (section 8) | |
| `PUSH_BACKEND` on staging, and the deploy run (section 9) | |
| Test push (section 10) | |
| Production | Later, in #36 |
| Key last rotated (section 11) | |

## 1. How it works

```
The app signs in, asks FCM for this phone's token
        |
        |  POST /api/notifications/devices/   {token, platform ANDROID, app_version}
        v
Backend stores the token for that user
        |
        |  something happens (a result is ready, a message, an alert ...)
        |  firebase-admin, with the service-account key, FCM HTTP v1
        v
Firebase Cloud Messaging delivers it to the phone
        |
        v
The phone shows the notification. A tap opens its deep link in the app
```

**Two kinds of file, two places:**

| File | What it is | Where it goes | How sensitive |
|---|---|---|---|
| `google-services.json`, one per flavor | Tells the **app** which Firebase project and app it belongs to | iltiam-mobile **repository secrets** `GOOGLE_SERVICES_JSON_DEV`, `GOOGLE_SERVICES_JSON_STAGING`, `GOOGLE_SERVICES_JSON_PROD`, base64. The mobile CI writes each one to `android/app/src/<flavor>/google-services.json` before the build | Low: its API key only works for our apps. Still never committed: git ignores every `google-services.json` |
| The service-account key | Lets the **backend** send pushes as the project | iltiam-deployment **staging Environment secret** `FCM_SERVICE_ACCOUNT_JSON`. The deploy writes it to `/srv/iltiam/env/staging/fcm-service-account.json` (mode 644), and [`compose.fcm.yml`](https://github.com/iltiam/iltiam-deployment/blob/main/compose.fcm.yml) mounts it read-only into the four backend containers and sets `FCM_CREDENTIALS_FILE` | **High:** whoever has it can send a push to every user of every flavor |

**One setting turns it on:** the staging Environment **variable** `PUSH_BACKEND`, set to `apps.notifications.push.FCMPushBackend` (the class `FCMPushBackend` in iltiam-backend's `apps/notifications/push.py`). Without it, the backend uses `apps.notifications.push.ConsolePushBackend`, which only **prints** pushes to its own log.

**What Firebase receives:** the phone's token, and each notification's title, text and deep link. It belongs in the ROPA as a processor (#6).

**What runs today:**
- `PUSH_BACKEND` isn't set on staging, so no push leaves the backend.
- The staging flavor of the app is built with `FCM_ENABLED` `true` (`config/flavors/staging.json` in iltiam-mobile). With a `google-services.json`, it starts Firebase and registers the phone; without one, it builds and runs without push. The dev and prod flavors keep `FCM_ENABLED` `false`.

## 2. Why one project for three apps

The three flavors have different package names, so Firebase treats them as three apps, each with its own tokens. A push meant for the staging app can't reach the prod app. One project means one service-account key to look after.

**Production** gets its own service-account key in its own GitHub Environment, in #36. #36 also decides whether production gets a separate Firebase project.

## 3. Before you start

- `<YOUR_GOOGLE_ACCOUNT>`, with 2-step verification on.
- `gh` signed in, with admin rights on `iltiam/iltiam-deployment` and `iltiam/iltiam-mobile` (`gh auth status`).
- **Git Bash** for the `base64` commands (section 6). PowerShell works too; section 6 shows both.
- For section 10: an Android phone (Android 10 or newer, with Google Play), a staging **patient** account, and SSH to the VM ([Runbook 1](01-oci-account-and-vm.md)).

## 4. The Firebase project (once)

1. Open [console.firebase.google.com](https://console.firebase.google.com) and sign in with `<YOUR_GOOGLE_ACCOUNT>`.
2. **Create a project** (it may say **Create a new Firebase project**). Name: `iltiam`. If Firebase adds a suffix to the project ID (`iltiam-1a2b3`), that's fine. Accept the terms **→ Continue.**
3. **AI assistance (Gemini) (check on screen):** off **→ Continue.**
4. **Google Analytics:** **off.** We don't use it, and it would collect data the ROPA would have to list **→ Create project.**
5. Wait until it says the project is ready **→ Continue.** You are on the project's **Project Overview**.
6. **A second owner,** so the project isn't lost with one account: gear icon ⚙ next to **Project Overview → Project settings → Users and permissions → Add member**. The backup owner from [`docs/secrets.md`](../secrets.md), section 3 (Omar-Nasri), role **Owner → Add member.** Skip this only if the team decides otherwise, and say so in As built.

**What you should see:** the project's name `iltiam` at the top left of the console.

## 5. The three Android apps (once)

On **Project Overview**, click **+ Add app** (or the Android icon under "Get started by adding Firebase to your app") **→ Android**. Do it three times, once per row:

| Flavor | Android package name (exactly) | App nickname | Save the file as |
|---|---|---|---|
| staging | `com.iltiamcare.app.staging` | `ILTIAM staging` | `<STAGING_FILE>`, e.g. `google-services-staging.json` |
| dev | `com.iltiamcare.app.dev` | `ILTIAM dev` | `<DEV_FILE>`, e.g. `google-services-dev.json` |
| prod | `com.iltiamcare.app` | `ILTIAM` | `<PROD_FILE>`, e.g. `google-services-prod.json` |

For each one:

1. Type the **package name** exactly as in the table. It comes from iltiam-mobile's `android/app/build.gradle.kts` (`applicationId` plus the flavor's suffix), and **it can't be changed later**: a typo means deleting the app and adding it again.
2. **App nickname:** as in the table. **Debug signing certificate SHA-1:** leave empty; push doesn't need it.
3. **Register app.**
4. **Download google-services.json.** Rename the download at once, as in the last column.
5. **Next** through the remaining steps without doing them: the iltiam-mobile repository already has the Gradle lines. **Continue to console.**

**What you should see:** **⚙ → Project settings → General → Your apps** lists three Android apps with the three package names.

## 6. Put the app files into iltiam-mobile

**Git Bash,** in the folder with the three files:

```bash
base64 -w0 google-services-staging.json | gh secret set GOOGLE_SERVICES_JSON_STAGING -R iltiam/iltiam-mobile
base64 -w0 google-services-dev.json     | gh secret set GOOGLE_SERVICES_JSON_DEV     -R iltiam/iltiam-mobile
base64 -w0 google-services-prod.json    | gh secret set GOOGLE_SERVICES_JSON_PROD    -R iltiam/iltiam-mobile
```

**Or PowerShell,** in the same folder:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\google-services-staging.json")) | gh secret set GOOGLE_SERVICES_JSON_STAGING -R iltiam/iltiam-mobile
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\google-services-dev.json"))     | gh secret set GOOGLE_SERVICES_JSON_DEV     -R iltiam/iltiam-mobile
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$PWD\google-services-prod.json"))    | gh secret set GOOGLE_SERVICES_JSON_PROD    -R iltiam/iltiam-mobile
```

`gh secret set` reads the value from the pipe, so nothing is shown on screen.

**Check** (names only):

```bash
gh secret list -R iltiam/iltiam-mobile --json name -q '.[].name' | grep GOOGLE_SERVICES
```

**What you should see:** `GOOGLE_SERVICES_JSON_DEV`, `GOOGLE_SERVICES_JSON_PROD`, `GOOGLE_SERVICES_JSON_STAGING`.

**What the mobile CI does with them:** a pull request builds the staging flavor; a push to `main` builds all three. Its step **Restore Firebase config files** prints `staging: Firebase config restored` for a flavor whose secret is set, and `no secret, building without Firebase config` otherwise. A flavor without its file still builds, without push.

**Keep `<STAGING_FILE>`** if you will build the app on your laptop (section 10.1, option B). Delete the other two, and empty the recycle bin.

## 7. Check the Cloud Messaging API

1. **⚙ → Project settings → Cloud Messaging.**
2. **Firebase Cloud Messaging API (V1):** it should say **Enabled**. New projects have it on.
3. **If it says Disabled:** its **⋮ menu → Manage API in Google Cloud Console → Enable**, then come back and reload the page.

Ignore anything about the **legacy** Cloud Messaging API: it is switched off for good, and the backend uses only V1.

## 8. The backend's key into GitHub (staging only)

1. **⚙ → Project settings → Service accounts.** **Firebase Admin SDK** is selected.
2. **Generate new private key → Generate key.** A JSON file downloads: `<KEY_FILE>`. **Don't open it in a chat, an editor that syncs, or a screenshot.**
3. In Git Bash or PowerShell, in the Downloads folder:

   ```bash
   gh secret set FCM_SERVICE_ACCOUNT_JSON --env staging -R iltiam/iltiam-deployment < <KEY_FILE>
   ```

   In PowerShell, `<` doesn't work; use `Get-Content -Raw <KEY_FILE> | gh secret set FCM_SERVICE_ACCOUNT_JSON --env staging -R iltiam/iltiam-deployment` instead.
4. **Delete `<KEY_FILE>`** and empty the recycle bin. Google keeps only the key's public half: the private key can't be downloaded again. If you need a new one, make a new key (section 11).
5. **Check** (names only):

   ```bash
   gh secret list --env staging -R iltiam/iltiam-deployment --json name -q '.[].name' | grep FCM
   ```

   **What you should see:** `FCM_SERVICE_ACCOUNT_JSON`.

**The key goes only here.** Never into iltiam-mobile, never into the app, never into a `.env` file on your laptop. **Production:** its own key in its own Environment, in #36.

## 9. Turn on push in staging

### 9.1 Order

**The key first (section 8), then `PUSH_BACKEND`.** With `PUSH_BACKEND` set and no key file, staging refuses to start: the backend's start-up check stops with `FCM_CREDENTIALS_FILE is not set`. The deploy then fails at `backend-migrate`, and the old backend keeps running (section 16).

### 9.2 The variable

```bash
gh variable set PUSH_BACKEND --env staging --body apps.notifications.push.FCMPushBackend -R iltiam/iltiam-deployment
```

It is a **variable, not a secret**: the deploy reads a `var` name only from variables (`env/backend.env.example`), so stored as a secret it would be ignored.

**Check:**

```bash
gh variable list --env staging -R iltiam/iltiam-deployment --json name,value -q '.[] | select(.name=="PUSH_BACKEND") | .value'
```

**What you should see:** `apps.notifications.push.FCMPushBackend`.

### 9.3 Deploy by hand

**Setting a secret or a variable deploys nothing.** The automatic deploys ([Runbook 9](09-cd-staging.md)) start only when an app repository publishes an image. So deploy now, by hand:

GitHub → **iltiam-deployment → Actions → deploy → Run workflow**, environment **staging → Run workflow.**

If you skip this, the next automatic deploy (of any service) writes the new settings anyway, at a moment nobody is watching. Deploy by hand now, and check it.

**What you should see in the run's log:**
- in **Render the env files**: a line `wrote …/fcm-service-account.json`;
- in **Deploy over SSH**, under `==> env files`: `fcm-service-account.json (644)`;
- the run is green.

### 9.4 Check on the VM

SSH to the VM as `ubuntu` ([Runbook 1](01-oci-account-and-vm.md)). The env folder belongs to `deploy`, so each command runs as `deploy`. Neither prints the key.

1. **The file is there, mode 644:**

   ```bash
   sudo -u deploy ls -l /srv/iltiam/env/staging/fcm-service-account.json
   ```

   **What you should see:** a line starting `-rw-r--r--` with `deploy deploy`. **Never `cat` this file.**
2. **The backend uses it:**

   ```bash
   sudo -u deploy /srv/iltiam/repo/scripts/compose.sh staging exec -T backend-web python manage.py shell -c "import os; from django.conf import settings as s; print(s.PUSH_BACKEND, os.path.isfile(s.FCM_CREDENTIALS_FILE))"
   ```

   **What you should see:** `apps.notifications.push.FCMPushBackend True`.

## 10. The test push

### 10.1 A staging build with push

You need both of these merged or set first:
- the iltiam-mobile change that sets `"FCM_ENABLED": true` in `config/flavors/staging.json`;
- `GOOGLE_SERVICES_JSON_STAGING` (section 6).

**Option A, from CI:** iltiam-mobile **→ Actions → CI →** a run after both of the above **→ Build debug APK**. Its log must show `staging: Firebase config restored`. Download the artifact `app-staging-debug-apk` from the run's page. It is kept for 3 days. If the run couldn't upload it (the organisation's artifact storage can be full), use option B.

**Option B, on your laptop,** in your iltiam-mobile checkout:

1. Copy `<STAGING_FILE>` to `android/app/src/staging/google-services.json`. Git ignores this file: `git status` must not list it.
2. Build:

   ```bash
   flutter build apk --debug --flavor staging --dart-define-from-file=config/flavors/staging.json
   ```

3. The APK is `build/app/outputs/flutter-apk/app-staging-debug.apk`.
4. Afterwards, delete `android/app/src/staging/google-services.json` and `<STAGING_FILE>`.

### 10.2 Install and sign in

1. Copy the APK to the phone and install it (Android asks you to allow installs from that source). The staging app installs next to any other ILTIAM flavor, because its package name is different.
2. Open it, and sign in as a staging **patient** with a real test number (a teammate who agreed). The code arrives by SMS ([Runbook 12](12-authentica.md)). Seeded `+96659999xxxx` accounts get no SMS, so use them only if you can read their `dev_otp_code` from the API.
3. If Android asks whether the app may send notifications: **Allow.** If it never asks: phone **Settings → Apps →** the staging app **→ Notifications →** on.
4. After sign-in the app registers the phone with the backend by itself. Leave it open for a few seconds.

### 10.3 Send it

Use the API docs page, `https://staging-api.iltiamcare.com/api/docs/`, as in [Runbook 12](12-authentica.md), section 9. **Never share a screenshot of this page:** it shows tokens.

1. Sign in **as the same patient** through the page: `POST /api/auth/login/`, then `POST /api/auth/login/verify/`. Copy the `access` value from the answer.
2. **Authorize** (top right) → paste it → **Authorize → Close.**
3. Open `POST /api/notifications/devices/test/` **→ Try it out → Execute.** It has no body.

**What you should see:**
- the answer `200`, with `"sent": 1` and one device with `"platform": "ANDROID"` and `"result": "SENT"`;
- on the phone, within a minute: **ILTIAM test notification**;
- a tap on it opens the app's notification list.

**Then once more with the app closed:** swipe the app away, lock the phone, and **Execute** again. The notification must still arrive.

The test push is limited to 10 an hour per user.

## 11. Rotate the key, or respond to a leak

**Rotate yearly, and after a staff change** ([`docs/secrets.md`](../secrets.md), section 6.5):

1. Section 8, steps 1 to 5: a new key into the same secret.
2. Deploy by hand (section 9.3), and check (section 9.4).
3. Send a test push (section 10.3).
4. Delete the old key: Google Cloud console ([console.cloud.google.com](https://console.cloud.google.com)), the project `iltiam` **→ IAM & Admin → Service accounts →** `firebase-adminsdk-…` **→ Keys →** the old key (its creation date tells you which) **→ Delete.**
5. Write the date in As built, and set a calendar reminder for a year later.

**After a leak, delete the old key first** (step 4), even though push stops until the new key is deployed. Then steps 1 to 3, and follow [`docs/secrets.md`](../secrets.md), section 7.

**`google-services.json`** never needs rotating. Download it again (**⚙ → Project settings → General → Your apps →** the app **→ google-services.json**) only if an app is deleted and added again, and update its secret (section 6).

## 12. iOS later

iOS push ships in v1.1 (iltiam-mobile#57): an APNs key uploaded under **⚙ → Project settings → Cloud Messaging → Apple app configuration**, an iOS app per flavor, and `GoogleService-Info.plist` files as iltiam-mobile secrets. The backend needs no change: it sends to iOS through the same FCM key.

## 13. Risks

| Risk | What could happen | What we do |
|---|---|---|
| The service-account key leaks | Anyone can send pushes to all our users | It lives only in the staging Environment and in one file on the VM (mode 644 inside a 700 folder, mounted read-only). Section 11 says what to do |
| One Google account owns the project | The project is lost with that account | A second owner (section 4, step 6). Both accounts use 2-step verification |
| A push is accepted but not shown | FCM delivery is best effort: battery saver or switched-off notifications can hold it back | In-app notifications always exist; pushes are an extra. Section 16 for checks |
| Data leaves our servers | Firebase receives tokens and each notification's title and text | It is listed as a processor in the ROPA (#6). Analytics is off |
| A wrong file in a flavor's secret | The build stops with `No matching client found for package name` | Section 5's table: one file per package name. Section 16 |
| Push on staging reaches real people | Test accounts with real numbers get pushes | Staging has only test accounts. Only the staging app's tokens are registered on staging |

## 14. Undo

| Step | How to undo | Note |
|---|---|---|
| Push on in staging (section 9) | `gh variable delete PUSH_BACKEND --env staging -R iltiam/iltiam-deployment`, then deploy by hand (section 9.3) | Pushes go back to the backend's log. The key file stays on the VM and does no harm |
| The key in GitHub (section 8) | **First** undo section 9. Then `gh secret delete FCM_SERVICE_ACCOUNT_JSON --env staging -R iltiam/iltiam-deployment`, and on the VM `sudo -u deploy rm /srv/iltiam/env/staging/fcm-service-account.json`, then deploy by hand | The deploy only writes files; it never removes one it no longer has, so the file must be removed by hand. Then delete the key in Google Cloud (section 11, step 4) |
| The app files in iltiam-mobile (section 6) | `gh secret delete GOOGLE_SERVICES_JSON_<FLAVOR> -R iltiam/iltiam-mobile` | That flavor then builds without push |
| `FCM_ENABLED` in the staging flavor | `git revert` of that commit, by PR, in iltiam-mobile | |
| An Android app (section 5) | **⚙ → Project settings → General → Your apps →** the app **→ Remove this app (check on screen)** | Its tokens stop working. Needed to fix a typo in a package name |
| The project (section 4) | **⚙ → Project settings → General → Delete project** | Firebase waits about 30 days before it really deletes it. Every key, app and token stops working |
| Changes to this repository | `git revert` the commit, by PR | |

## 15. Before you ask for help

- `PUSH_BACKEND` on staging: section 9.2's check.
- The deploy's log after section 9.3.
- The answer of the test push (section 10.3): only `sent`, `dead`, `failed` and each device's `result`. **Not** the device `id` and not the token.
- Phone model and Android version.

## 16. If something fails

| What you see | Likely cause | What to do |
|---|---|---|
| Deploy: `rendering … failed` and `FCM_SERVICE_ACCOUNT_JSON is not a JSON object` | The secret holds something other than the key file's contents | Section 8 again, with `<` (or `Get-Content -Raw`), never a paste |
| Deploy: `backend migrations failed`, and the backend's log says `FCM_CREDENTIALS_FILE is not set` | `PUSH_BACKEND` is set, but `FCM_SERVICE_ACCOUNT_JSON` isn't (section 9.1) | The old backend keeps running. Set the key (section 8) and deploy by hand, or delete `PUSH_BACKEND` |
| Same, with `FCM_CREDENTIALS_FILE is not a Firebase service-account file` | The secret holds a `google-services.json`, not the key | Section 8 again with the right file: it is the one from **Service accounts**, and its `type` is `service_account` |
| Deploy: `fcm-service-account.json must be mode 644` | Someone changed the file's mode on the VM | `sudo -u deploy chmod 644 /srv/iltiam/env/staging/fcm-service-account.json`, then deploy again |
| Mobile CI: `base64: invalid input` | The secret wasn't base64 | Section 6 again for that flavor |
| Mobile build: `No matching client found for package name 'com.iltiamcare.app.staging'` | The staging secret holds another flavor's file | Section 6 again with `<STAGING_FILE>` |
| Firebase refuses to make a key (**Generate new private key** greyed out or an error about a policy) | A Google Cloud organisation policy blocks key creation | Not expected on a personal account. Check you're in the right Google account; otherwise ask for help |
| Test push: `409 NO_PUSH_DEVICE` | The phone isn't registered | Is the build from after the `FCM_ENABLED` change, with `staging: Firebase config restored` in the CI log? Is the phone signed in as the **same** user? Close and open the app: it registers again at start. Phones without Google Play can't get a token |
| Test push: `503 PUSH_UNAVAILABLE` | The backend can't use FCM | Section 9.4. If `PUSH_BACKEND` is right, check section 7 and that the key wasn't deleted |
| A device's `result` is `DEAD` | FCM says that token is gone: the app was reinstalled, or its data was cleared | It was removed. Open the app again so it registers, then send again |
| A device's `result` is `FAILED` | A temporary FCM error, or the API is off | Send again after a minute. Then section 7. On the VM: `sudo -u deploy /srv/iltiam/repo/scripts/compose.sh staging logs --tail 200 backend-web backend-worker \| grep -c 'FCM send failed'`. **Don't paste the log lines anywhere** |
| `SENT`, but nothing on the phone | The phone held it back | Phone **Settings → Apps →** the staging app **→ Notifications:** on. Battery saver and Do Not Disturb off. Try with the app closed and with it open |

## 17. Verified

The **When** column says when a row can pass:
- **this PR:** in CI, before the merge;
- **console:** the Firebase console or `gh`;
- **after the deploy:** section 9.3 is done;
- **with a build:** a staging build with push (section 10.1).

The **Verified** column records the date each row last passed.

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | CI | the pull request's checks | `docs` (MkDocs strict) and `env-check` green | this PR | |
| 2 | Project | section 4 | project `iltiam`, Analytics off, two owners | console | |
| 3 | Android apps | section 5 | three apps with exactly the three package names | console | |
| 4 | App files in iltiam-mobile | section 6, check | three `GOOGLE_SERVICES_JSON_*` names | console | |
| 5 | Cloud Messaging API (V1) | section 7 | Enabled | console | |
| 6 | Key in the staging Environment | section 8, step 5 | `FCM_SERVICE_ACCOUNT_JSON` | console | |
| 7 | `PUSH_BACKEND` on staging | section 9.2, check | `apps.notifications.push.FCMPushBackend` | console | |
| 8 | Manual deploy | section 9.3 | green; `fcm-service-account.json (644)` in the log | after the deploy | |
| 9 | File on the VM | section 9.4, step 1 | `-rw-r--r--`, `deploy deploy` | after the deploy | |
| 10 | Backend setting | section 9.4, step 2 | `apps.notifications.push.FCMPushBackend True` | after the deploy | |
| 11 | Staging build with Firebase | section 10.1 | `staging: Firebase config restored` (CI), or a local build with the file | with a build | |
| 12 | Test push, app open (acceptance) | section 10.3 | `200`, `"result": "SENT"`; the notification shows on the phone | with a build | |
| 13 | Test push, app closed | section 10.3, last step | the notification shows | with a build | |
| 14 | Tap opens the app | section 10.3 | the notification list opens | with a build | |
| 15 | Key rotation reminder | section 11, step 5 | a calendar entry a year ahead | console | |

**Record the results as a comment on issue #14:** pass or fail per row, with the date, the phone model and the Android version. **Never include** a key, a token, a project number, an app ID or a phone number.

## 18. Security notes

- **The key stays on the server side.** It is only in the staging GitHub Environment and in one file on the VM: mode 644 inside a 700 folder that only `deploy` can open, mounted read-only (`compose.fcm.yml`). The 644 exception, and why it is safe, is in [`docs/secrets.md`](../secrets.md), section 1.
- **The app files are not secrets in the same way,** but they are never committed: git ignores every `google-services.json`, and the CI writes them from secrets for the build only.
- **Push only.** Firebase isn't used for sign-in, analytics or crash reports. The backend's only Firebase code is `apps/notifications/push.py`, and a test keeps it that way.
- **Dead tokens are removed** as soon as FCM reports them, so pushes don't pile up for phones that are gone.

## 19. What comes next

- **iltiam-mobile#31:** push in the app (permission prompt, token refresh, the notification screens).
- **iltiam-mobile#24:** staging builds for testers, so section 10.1 needs no laptop build.
- **#36:** production's key in the production Environment, `PUSH_BACKEND` there (production refuses to start without real push), and whether production gets its own Firebase project.
- **iltiam-mobile#57 (v1.1):** iOS push (section 12).
- **#6:** Firebase as a processor in the ROPA.
