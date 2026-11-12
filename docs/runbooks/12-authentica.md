# Runbook 12: Authentica account, default sender and API key for phone codes

- **Issue:** iltiam/iltiam-deployment#15 (DEP-14). **Decision record:** [ADR-0004](../adr/0004-hosting.md), Decision 5, with one change for now (section 2). **Backend side:** iltiam/iltiam-backend#74, #103 and #104 (done); the doctor activation flow came with iltiam-backend#127 and iltiam/iltiam-web#68. **WhatsApp:** #61.
- **Who:** the person who can log in to the Authentica account (today only ben-fatah), with admin rights on `iltiam/iltiam-deployment` and SSH to the VM. No cloud experience needed; follow the steps in order.
- **Time:** about 30 minutes for sections 4 to 7, and about an hour for sections 8 and 9. A custom sender name (section 12) takes 1 to 2 weeks.
- **Result:**
  - an Authentica application for ILTIAM, with its own API key;
  - the key in the staging GitHub Environment, and never anywhere else;
  - a safe test that proves our own code reaches a Saudi phone;
  - real SMS codes on staging for sign-in, password reset and a new user's first password (since 2026-11-11, checked end to end on 2026-11-12).

> **This repository is public. Never paste a secret or a real phone number into this runbook, an issue, a PR, a commit or a chat.** Use the placeholders below. When you record a test, mask the number: first five characters and last two only.

| Placeholder | Meaning |
|---|---|
| `<YOUR_PHONE>` | Your own Saudi number, `+9665XXXXXXXX` |
| `<DOCTOR_PHONE>`, `<PATIENT_PHONE>` | Real numbers of teammates who agreed to receive test messages. Each account needs its own number |
| `<ENV>` | `staging` or `production`: the GitHub Environment |
| `<NEW_TAG>` | The backend image tag that contains iltiam-backend#103, `sha-<7 characters>` |

Authentica's menu names can change, and those below come from the dashboard as seen on 2026-11-07. If a menu isn't where this says, look for its name on the page. Steps marked **(check on screen)** weren't confirmed click by click.

## As built

Filled in when the steps are done. Names and dates only: never a key or a full phone number.

| Item | Value |
|---|---|
| Account | Existing account owned by ben-fatah, shared with the Nakhlah project (same balance). Only ben-fatah logs in |
| Application (section 4) | `ILTIAM`: Numeric, 6 digits, validity 300 s, primary SMS, fallback None, no sender configured, 1 API key, 2026-11-07 |
| Sender name (section 2) | None registered. The default sender `Authentica` is used |
| Templates (section 5) | 8 (Arabic) and 7 (English) |
| Safe test (section 6) | Passed from the VM, 2026-11-07 |
| Staging key in GitHub (section 7) | `AUTHENTICA_API_KEY` set 2026-11-07 |
| `SMS_BACKEND` on staging (section 8) | `apps.notifications.sms.AuthenticaSMSBackend`, set 2026-11-11, with the variables `AUTHENTICA_SMS_CODE_MODE=send_otp`, `AUTHENTICA_SMS_TEMPLATE_ID_AR=8`, `AUTHENTICA_SMS_TEMPLATE_ID_EN=7` |
| Staging images | Backend `sha-14223c2` (iltiam-backend#127, API `api-v0.5.0`) and web `sha-5f1283f` (iltiam/iltiam-web#68), deployed 2026-11-12. The current tags are always in `env/staging.versions` |
| First password and password reset | On the web at `/set-password` (new users) and `/forgot-password`: one page, the same `password/reset/request/` and `password/reset/confirm/` calls, with an SMS code. A Clinic Admin or Super Admin can press **Resend invite** on a pending doctor: a new SMS code, and a bilingual email with the `/set-password` link. Since iltiam-backend#127 and iltiam/iltiam-web#68, 2026-11-12 |
| WhatsApp | **Not working: blocked by Authentica/Meta template review.** Authentica answers HTTP 422 while the portal shows "WhatsApp: In review". `AUTHENTICA_WHATSAPP_TEMPLATE_ID` is not set. Retest after approval: #61 |
| Production | Later, in #36: its own application and API key, and the sender name |
| Key last rotated (section 13) | |

## 1. How it works

```
Backend makes a 6-digit code and stores it hashed
        |
        |  POST https://api.authentica.sa/api/v2/send-otp
        |  header X-Authorization, body: method sms, phone, otp (our code), template_id
        v
Authentica puts the code into template 8 (Arabic) or 7 (English)
        |
        v
The phone shows the SMS from "Authentica"
        |
        v
The user types the code. The backend checks it against its own hash
```

**Authentica only delivers the message.** The backend makes and checks every code (ADR-0004), and never calls Authentica's `/verify-otp`.

**What runs today on staging:**
- `SMS_BACKEND` is the Authentica backend in `send_otp` mode (section 8), so codes reach phones from the default sender. The backend no longer prints codes to its log.
- The reserved test numbers `+96659999xxxx` (in `OTP_DEV_ECHO_NUMBERS`) are never sent to Authentica (iltiam-backend#104). Their code comes back in the API's `dev_otp_code`, only on staging, and they cost nothing.
- A new doctor or patient sets a first password on the web at `/set-password` with an SMS code, not with a link (iltiam-backend#127, iltiam/iltiam-web#68).
- WhatsApp codes go to the same `/send-otp` with `method: whatsapp`. They fail until Authentica and Meta approve the WhatsApp templates (#61).

## 2. Why we use the default sender

**ADR-0004 planned for `/send-sms`**, with our own text and our own sender name. Authentica support answered in writing on 2026-11-07:

| Question | Answer from support |
|---|---|
| Does `/send-sms` work without a registered sender name? | **No.** `/api/v2/send-sms` needs a registered sender name |
| What does registering a sender name need? | A Commercial Registration, a Chamber of Commerce letter, SAR 264.50, and 1 to 2 weeks |
| What can students without a Commercial Registration use? | The default sender `Authentica`, which works with OTP templates (`/api/v2/send-otp`) |
| What does it cost? | 1 point per local SMS; 1 point = 0.11 SAR |

We have no Commercial Registration, so the Senders tab is empty and staging uses the default sender. The issue's acceptance criteria allow this as the interim path.

**What this means for users and the team:**
- The phone shows the sender as `Authentica`, not `ILTIAM`.
- The text is the template's, not the bilingual text in the backend (`MESSAGES` in `apps/accounts/otp.py`).
- **Only codes go out.** With no sender name, messages that need `/send-sms` can't be sent: welcome messages, the "your password was changed" message, and the SMS copies of alerts and reminders. iltiam-backend#103 records those as failed, with no cost.
- **Production isn't solved by this.** Its settings still require a sender name, because welcome messages, alerts and breach notices need `/send-sms`. That decision belongs to #36.

## 3. Before you start

1. Read the warning at the top of this runbook.
2. On your laptop, have the [GitHub CLI](https://cli.github.com) signed in (`gh auth status`), and this repository's folder open in **Git Bash**.
3. Check that `ssh iltiam` opens the VM ([Runbook 1](01-oci-account-and-vm.md)).
4. Have your phone next to you, with a signal.

## 4. Account and application

### 4.1 The account

Our account already exists, at [portal.authentica.sa](https://portal.authentica.sa), and it is shared with the Nakhlah project. If you ever need a new one, use [Sign up](https://portal.authentica.sa/signUp).

Turn on two-step sign-in if the portal offers it **(check on screen)**. Don't share the login: anyone who has it can spend the balance and can read the SMS logs.

### 4.2 The application

Each project gets its own application, so ILTIAM has its own key and can't use Nakhlah's.

1. Open **My Applications** and create a new application (or [go there directly](https://portal.authentica.sa/applications/create)).
2. Use these values:

   | Field | Value | Why |
   |---|---|---|
   | Name | `ILTIAM` | Shown where a template uses `{{app_name}}` |
   | OTP type | Numeric | Our codes are digits |
   | Digits | 6 | Our codes have 6 digits |
   | Validity | 300 seconds | Only Authentica's own `/verify-otp` would use it, and we never call that |
   | Primary service | SMS | |
   | Fallback service | None | The backend chooses other channels itself. A sign-in code is never re-sent elsewhere silently |
   | Sender | Leave empty | The default sender is used (section 2) |

3. Save.

**What you should see:** `ILTIAM` in **My Applications** next to the Nakhlah applications, with those values.

### 4.3 The API key

1. Open **My Applications → ILTIAM → API keys (check on screen)** and create a key.
2. Copy it, and keep the page open for sections 6 and 7.
3. Don't save it in a file or a note, and don't send it in a chat. GitHub can't show it again later, and that's fine: if you lose it, create a new one (section 13).

## 5. Templates

An SMS sent through `/send-otp` uses a template. `template_id` picks one, and **that's also how the language is picked**: the API has no language field. Without an ID, the account's default is used. The IDs come from the dashboard's **Templates** page.

| ID | Language | Text |
|---|---|---|
| **8** | Arabic | `{{otp}} هو رمز التحقق الخاص بك.` |
| **7** | English | `{{otp}} is your verification code.` |
| none (default) | English | `XXXXXX is your verification code. For your security, do not share this code.` |

**Why these two:** they are short, they fit both sign-in and password codes, and they state no time limit. A sign-in code lasts 5 minutes and a password code lasts 10, so a template that says "valid for 5 minutes" would be wrong for one of them.

**If you ever choose another template:** it must be for SMS, contain `{{otp}}`, use neutral wording and state no time. Test it with section 6 before using it.

## 6. The safe test from the VM

[`scripts/check-authentica.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/check-authentica.sh) sends one real SMS, exactly as the backend will after iltiam-backend#103, and shows the balance before and after. **Each run costs 1 point.**

**Why it's a file you copy:** long pastes into the SSH terminal get scrambled, and a pasted line can end up typed into a hidden prompt.

**Why it's safe:** the key is typed at a hidden prompt, and reaches `curl` through a pipe. So it never shows on screen, and never goes into the shell history, the process list or a file.

1. On your laptop, in this repository's folder (a checkout made after `.gitattributes` was added, so the script has LF line endings):

   ```bash
   scp scripts/check-authentica.sh iltiam:~
   ssh iltiam
   ```

2. On the VM:

   ```bash
   bash ~/check-authentica.sh send-otp
   ```

3. Answer the three prompts:

   | Prompt | Answer |
   |---|---|
   | `API key (hidden):` | Paste the key, then press Enter. Nothing appears; that's normal |
   | `Your phone (+9665XXXXXXXX):` | `<YOUR_PHONE>` |
   | `Template ID (press Enter for the default):` | `8`. Run the script again with `7` to test English |

**What you should see:**

```
--- balance before
{"success":true,"data":{"balance":...},"message":"..."}
HTTP 200
--- sending. THE SMS MUST SHOW THIS CODE: 123456
{"success":true,"data":null,"message":"..."}
HTTP 200
--- waiting 20 seconds
--- balance after
{"success":true,"data":{"balance":...},"message":"..."}
HTTP 200
--- the code we sent: 123456
PASS only if the SMS shows exactly this code. Now run: clear
```

The code is random on each run, so yours will differ. It's only a test code and can't sign anyone in.

| Result | Meaning | What to do |
|---|---|---|
| **Pass:** HTTP 200, and the SMS shows **exactly** the printed code, from `Authentica`, in the right language, and the balance drops by 1 | The route works | Run `clear`, then record the result on #15 with a masked number |
| HTTP 200, but the SMS shows a **different code** | Authentica ignored our code, so the backend would refuse what the user types | **Stop.** Don't turn on section 8. Ask the team: this needs a new decision |
| HTTP 200, but no SMS after 5 minutes | Accepted but not delivered | Look in **SMS → Logs** on the dashboard. Don't send again and again; each try costs a point |
| HTTP 401 | Wrong key | The script stops before sending. Copy the key again |
| Any `ERROR:` line | The script explains the problem | Section 16 |

**After the test:**

1. Run `clear`, then remove the copy. It holds no secret, but there's no reason to keep it there:

   ```bash
   rm ~/check-authentica.sh
   exit
   ```

**The result on 2026-11-07,** from the VM, to `+96654*****13`, with the default sender and our own `otp`. It came from the same request in an earlier hidden-prompt script, before this file existed:

| Template | HTTP | SMS | Cost |
|---|---|---|---|
| 8 (Arabic) | 200 | Showed exactly our code | 1 point |
| 7 (English) | 200 | Showed exactly our code | 1 point |

`GET /api/v2/balance` works with the `X-Authorization` header, and reading the balance costs nothing. Ignore the `/api/v1` and `Bearer` example in the dashboard's quick start: the [API docs](https://docs.authentica.sa) and the backend use v2 with `X-Authorization`.

## 7. Put the key into GitHub

On your laptop:

```bash
gh secret set AUTHENTICA_API_KEY --env staging -R iltiam/iltiam-deployment
```

Paste the key at the prompt, then press Enter. Nothing is shown or saved on the laptop. Then clear your clipboard, for example by copying some other text.

**Check** (names only; no command can show a secret's value):

```bash
gh secret list --env staging -R iltiam/iltiam-deployment --json name -q '.[].name' | grep AUTHENTICA
gh variable list --env staging -R iltiam/iltiam-deployment --json name -q '.[].name' | grep -E 'SMS_BACKEND|AUTHENTICA' || echo "no variables yet: correct"
```

**What you should see:** `AUTHENTICA_API_KEY`, then `no variables yet: correct`.

**The key reaches the VM with the next deploy,** and does nothing there until `SMS_BACKEND` is set.

**Don't set these now:**
- `SMS_BACKEND`: section 8.
- `AUTHENTICA_SENDER_NAME`: only when Authentica approves a sender (section 12). It is a **variable, not a secret**: the deploy reads a `var` name only from variables, so stored as a secret it would be ignored.

**Production:** its own key in its own application, in #36.

## 8. Turn on real SMS

**Done on staging on 2026-11-11,** with backend `sha-8097a18` (iltiam-backend#103 and #122). The steps stay here for production (#36) and in case it has to be done again.

**Do it only when all of this is true:**
- iltiam-backend#103 is merged, and its image `<NEW_TAG>` is published;
- section 6 has passed.

The three setting names below come from iltiam-backend#103 (merged in `c6e16a6`, `config/settings/base.py`). Step 1's template names and `check-env.sh` checks are done.

1. **Open a PR in this repository** that:
   - adds the three new names to `env/backend.env.example`, each tagged `# var, optional:`;
   - moves `BACKEND_IMAGE` in `env/staging.versions` to `<NEW_TAG>`;
   - extends `scripts/check-env.sh` for the new names.

   Merge it. Merging deploys nothing.

2. **Set the variables on your laptop, with `SMS_BACKEND` last:**

   ```bash
   REPO=iltiam/iltiam-deployment
   gh variable set AUTHENTICA_SMS_CODE_MODE --env staging --body send_otp -R "$REPO"
   gh variable set AUTHENTICA_SMS_TEMPLATE_ID_AR --env staging --body 8 -R "$REPO"
   gh variable set AUTHENTICA_SMS_TEMPLATE_ID_EN --env staging --body 7 -R "$REPO"
   gh variable set SMS_BACKEND --env staging --body apps.notifications.sms.AuthenticaSMSBackend -R "$REPO"
   ```

3. **Deploy:** GitHub → **Actions → deploy → Run workflow**, environment `staging`.

4. **Check the setting on the VM,** without showing the key. After `ssh iltiam`, as the `ubuntu` user:

   ```bash
   cd /tmp && sudo -u deploy /srv/iltiam/repo/scripts/compose.sh staging exec -T backend-web python manage.py shell -c "from django.conf import settings as s; print(s.SMS_BACKEND, bool(s.AUTHENTICA_API_KEY))"
   ```

   **What you should see:** `apps.notifications.sms.AuthenticaSMSBackend True`.

   **Why `cd /tmp` first:** `sudo -u deploy` keeps your current folder, and `deploy` can't read `/home/ubuntu`, so `compose.sh` stops with `stat .: permission denied`. Every VM command in this runbook starts this way.

5. **Run section 9.**

**Seeded accounts (`+96659999xxxx`)** are safe since iltiam-backend#104: their codes never go to Authentica and cost nothing (checked 2026-11-12). Their code comes back as `dev_otp_code`, only on staging and only for numbers listed in `OTP_DEV_ECHO_NUMBERS`.

## 9. End-to-end checks

Do these after section 8 and fill in section 17.

**Where to run them:**
- **The web app:** `https://staging-app.iltiamcare.com`. Since iltiam/iltiam-web#68 it does sign-in with a code, a new code after a 60-second countdown, the other channels when a send fails, `/set-password` for a new user's first password, `/forgot-password`, and **Resend invite** on the doctor lists.
- **The API docs page:** `https://staging-api.iltiamcare.com/api/docs/`, for the mobile sign-in calls. Open an endpoint, press **Try it out**, fill in the fields and press **Execute**, with no long terminal pastes. Never share a screenshot of this page: it can show passwords and tokens.
- **The mobile app:** row 13 (iltiam/iltiam-mobile#25).

**Limits to remember while testing:**
- 60 seconds between resends, and **5 codes per hour for one user**. Sign-in, resend, Resend invite and password codes all count.
- After that limit, sign-in shows "too many requests". `/forgot-password` and `/set-password` still answer "If this number has an account…" but send nothing. That is on purpose: the page answers the same for every number, so it doesn't reveal which numbers have accounts. Wait an hour.
- 5 wrong tries on a code ends that code; 5 failures on an account lock it for 10 minutes.
- Each real SMS costs 1 point. Plan the tests so one number doesn't need more than 5 codes in an hour.

**The checks:**

1. **Super Admin sign-in.** Sign in on the web app. A code reaches the Super Admin's phone. This costs a point even if you then use the authenticator app.
2. **New doctor, first password.** As Clinic Admin or Super Admin, create a doctor with `<DOCTOR_PHONE>` and an email address, or press **Resend invite** on a doctor whose status is pending. The code SMS arrives, and the doctor's inbox gets the bilingual invitation with the `/set-password` link. There's no welcome SMS in this mode. On `/set-password`, enter the phone, the code and a new password: the page says the account is active, and the doctor list shows **Active**.
3. **Doctor sign-in on the web.** The right code signs in and the doctor's dashboard opens. A wrong code shows "That code is not right…". On the code screen, after the 60-second countdown, **Send a new code by SMS** sends a new one.
4. **Language.** A user with `preferred_language` `ar` gets template 8, and one with `en` gets template 7. The Arabic reads correctly.
5. **Password reset.** **Forgot password?** on the sign-in page (`/forgot-password`): the same page and the same calls as check 2. An unknown number gets the same "If this number has an account…" answer.
6. **New patient.** The doctor registers a patient with `<PATIENT_PHONE>`. Set the password as in check 5.
7. **Patient sign-in, stand-in for the app.** The calls the app will make: `POST /api/auth/login/`, then `POST /api/auth/login/verify/`.
8. **WhatsApp.** After a sign-in, wait for the 60-second countdown, then press **Send by WhatsApp** (or `POST /api/auth/login/resend/` with `channel` `WHATSAPP`). **The code must work.** **Today it fails: WhatsApp is blocked by Authentica/Meta template review.** Authentica answers HTTP 422 and the log shows `OTP delivery by WHATSAPP failed for user …: Authentica refused the message: HTTP 422`. Retest after approval (#61).
9. **No codes in the logs.** On the VM, after `ssh iltiam`:

   ```bash
   cd /tmp && sudo -u deploy /srv/iltiam/repo/scripts/compose.sh staging logs --since 3h backend-web backend-worker | grep -cE 'SMS to|WHATSAPP code to'
   ```

   **What you should see:** `0`.

   **What this proves, and what it doesn't:** `SMS to …` and `WHATSAPP code to …` are the lines the console backend writes, with the code, when `SMS_BACKEND` is unset. So `0` shows that the console backend is off. The Authentica backend never logs a code, so with it on the count is always `0`. A non-zero count can also come from a failure line such as `Welcome SMS to patient … failed`, which holds no code: read the matching lines on the VM before you worry, and never paste them anywhere.

10. **Cost.** The balance dropped by the number of messages sent, and no more.

## 10. Monthly balance check

**Use a calendar reminder and the dashboard.** It needs no key, no VM and no new service, so it fits the free VM.

1. Add a repeating reminder for the 1st of each month, and one more for demo week.
2. Log in to [portal.authentica.sa](https://portal.authentica.sa) and read the balance.
3. **Below 100 points:** top up. **Before a demo:** have at least 200.
4. **If it dropped much more than expected:** look in **SMS → Logs**. It may be Nakhlah's use, because the balance is shared. If you can't explain it, treat it as a leak (section 13).

**From the API:** `bash ~/check-authentica.sh balance` reads the balance and sends nothing (copy the script as in section 6). It needs a key at the prompt, and the normal monthly check doesn't. `GET /api/v2/balance` answers in [credits](https://docs.authentica.sa/api-reference/balance-monitoring/get-current-balance.md), the same unit the dashboard calls points.

## 11. Cost

| Item | Cost | Source |
|---|---|---|
| One local SMS with template 7 or 8 | 1 point | Measured 2026-11-07, and support. Again 2026-11-12 through the backend: **SMS → Logs** shows "Paid, 1 pt" per SMS |
| A code for a seeded `+96659999xxxx` account | Free: never sent | Measured 2026-11-12 |
| One point | 0.11 SAR | Support. The [public price list](https://authentica.sa/en/pricing-en/) starts at 240 SAR for 2,000 credits, about 0.12 SAR each |
| 100 SMS | about 11 SAR | Calculated |
| Reading the balance | Free | Measured 2026-11-07 |
| Custom sender name | SAR 264.50, once | Support; ask whether it renews |

Support didn't say whether long messages cost more. Templates 7 and 8 are short and cost 1 point each. Measure again with section 6 before using any longer template.

**What spends points:** every sign-in code, including a Super Admin's; every password code; every resend. A patient on a remembered device skips the code.

**Not spending points in this mode:** welcome messages, password-changed messages, and the SMS copies of alerts and reminders, because they aren't sent (section 2).

## 12. A custom sender name later

Do this only when the project has a Commercial Registration.

1. Prepare what support asked for: the Commercial Registration, a Chamber of Commerce letter, and SAR 264.50. Allow 1 to 2 weeks.
2. Request the name `ILTIAM` under **SMS → Senders**. Drafts appear under **Senders Drafts (check on screen)**. Authentica's [FAQ](https://authentica.sa/resources/faq) covers registering and renewing a sender, and a request stuck "Under Review". For help: [support on WhatsApp](https://wa.me/966536553944) or Support@authentica.sa.
3. When it's approved:
   - send a test through `/send-sms` with the new name. The script has no mode for this yet, so add one, with the body `phone`, `message`, `sender_name`;
   - set the **variable** `AUTHENTICA_SENDER_NAME` to the exact approved name;
   - change `AUTHENTICA_SMS_CODE_MODE` to `send_sms` (iltiam-backend#103), and deploy.
4. Run section 9 again. Welcome messages and password-changed messages should now arrive too.

## 13. Rotate the key, or respond to a leak

**Rotate after a staff change or a suspected leak** (`docs/secrets.md`, section 2):

1. **My Applications → ILTIAM → API keys (check on screen):** create a new key.
2. Update the secret (section 7), then deploy staging.
3. Sign in once to check that a code still arrives.
4. Delete the old key in the dashboard.

**After a leak, delete the old key first, even if SMS is down for a while.** Then look in **SMS → Logs** and at the balance for messages you didn't send, and follow `docs/secrets.md`, section 7.

## 14. Risks

| Risk | What could happen | What we do |
|---|---|---|
| Points run out during the demo | Sign-in fails, and WhatsApp doesn't work yet (#61) | Section 10: check that morning, keep at least 200, and top up at least 3 days before, because the FAQ shows recharges can be delayed. Backups: patients on a remembered device skip the code; Super Admins can use the authenticator app |
| Shared account with Nakhlah | Both projects spend one balance. A leaked key from either project spends it too | Separate keys per application, and only one person logs in. Ask #36 to use a separate account for real patients |
| Rate limits | Authentica publishes none. The backend retries a 429 once, then reports a failed send | Our own limits keep sends low (section 9). Ask support before any large test |
| Codes in logs | While `SMS_BACKEND` is unset, the staging backend logs codes. Authentica's SMS logs may show them too **(check on screen)** | Check 9 proves the backend stops. Never paste logs into an issue or chat. Only one person logs in to the portal |
| Phone numbers leave our servers | Authentica receives users' phone numbers, and it is a Saudi provider | It belongs in the ROPA as a processor (#6). Test numbers only with the person's consent |
| SMS accepted but not delivered | HTTP 200 means accepted, not delivered, so a user may wait | The backend tells the apps to offer other channels after 30 seconds, once the apps can (iltiam/iltiam-web#28, iltiam/iltiam-mobile#25) |
| Seeded test numbers | Real sends to `+96659999xxxx`: cost, and possibly a stranger | Since iltiam-backend#104 they are never sent to Authentica (checked 2026-11-12) |
| Alerts have no SMS copy | Critical alerts go only by their other channels. On staging, push works only once [Runbook 11](11-firebase.md) is done | Accepted for the demo. Push per [Runbook 11](11-firebase.md); the SMS copy needs a sender name (section 12) |
| The default sender stops working | Codes stop | Section 6 finds it quickly. Ask support, then section 15 |

## 15. Undo

| Step | How to undo | Note |
|---|---|---|
| Sent SMS, points spent | Can't be undone | Points aren't given back |
| Turned on real SMS (section 8) | `gh variable delete SMS_BACKEND --env staging -R iltiam/iltiam-deployment`, then deploy staging | Codes go back to the log and stop reaching phones. Treat this as temporary |
| The new image | Put the old tag back in `env/staging.versions`, merge, deploy ([Runbook 5](05-compose-stack.md), section 9.4) | Delete `SMS_BACKEND` first: the old image can't send through `/send-otp` |
| The three new variables | `gh variable delete <NAME> --env staging -R iltiam/iltiam-deployment` | Harmless if left in place: the old image doesn't read them |
| The key in GitHub (section 7) | `gh secret delete AUTHENTICA_API_KEY --env staging -R iltiam/iltiam-deployment`, then deploy | Delete `SMS_BACKEND` first, or the deploy fails |
| The API key | Delete it in the dashboard | Any backend still using it gets a 401 |
| The application | Delete it in **My Applications (check on screen)** | Nakhlah's applications aren't affected |
| A sender request | Withdraw it with support | The fee may not come back; ask first |
| Changes to this repository | `git revert` the commit, by PR | |

## 16. If something fails

| What you see | Likely cause | What to do |
|---|---|---|
| `Could not resolve hostname iltiam` | `ssh` can't find your SSH config | [Runbook 1](01-oci-account-and-vm.md), SSH section. If your config file isn't in the default place, add `-F <PATH_TO_CONFIG>` to `ssh` and `scp` |
| `$'\r': command not found` | The script has Windows line endings | Copy it from a checkout made after `.gitattributes` was added ([Runbook 1](01-oci-account-and-vm.md), section 9.1) |
| `ERROR: no key entered` | The paste didn't reach the prompt | Run it again. In some terminals, paste with a right-click |
| `ERROR: the key contains a quote or a backslash` | The copied text isn't a clean key | Copy only the key from the dashboard |
| `ERROR: the phone must look like +9665XXXXXXXX` | Wrong format | Use `+966`, then the nine digits, without the leading `0` |
| `ERROR: could not reach Authentica` | Network or DNS problem | Run `curl -sI https://api.authentica.sa` on the VM. Try again later |
| HTTP 401 | Wrong or deleted key | Check the key in the dashboard, or create a new one |
| HTTP 200 but no SMS | Delivery problem | **SMS → Logs** on the dashboard, then ask support with the time of the send |
| Deploy: `backend migrations failed`, and the log says `Delivery settings ...: AUTHENTICA_API_KEY is not set` or `AUTHENTICA_SENDER_NAME is not set` | `SMS_BACKEND` is set, but something it needs is missing. With the old image, a sender name is always needed | The old backend keeps running. Delete `SMS_BACKEND`, and read section 8 before setting it again |
| Web sign-in sits on the code screen, and no SMS arrives | The send failed, or it is slow | The code screen offers a new code after 60 seconds, and the other channels at once when the send failed. Check the balance and **SMS → Logs**. For the error, on the VM: `cd /tmp && sudo -u deploy /srv/iltiam/repo/scripts/compose.sh staging logs --tail 100 backend-web \| grep 'OTP delivery'`. Don't paste the output anywhere |
| No code arrives on `/forgot-password` or `/set-password`, and the page still says "If this number has an account…" | **Check the limit of 5 codes per hour for one user** (sign-in, resend, Resend invite and reset codes all count). The page answers the same either way, so it doesn't reveal which numbers have accounts. Or the number has no account | **Wait 1 hour,** then try again. Sign-in with the same number shows "too many requests" while the limit lasts. **SMS → Logs** shows the codes already sent |
| `RATE_LIMITED`, "too many requests" | Resend too soon, or 5 sends in an hour | Wait, as in section 9 |
| **Send by WhatsApp** fails; the log says `OTP delivery by WHATSAPP failed …: Authentica refused the message: HTTP 422` | **WhatsApp is blocked by Authentica/Meta template review** (portal: "WhatsApp: In review"). Support: no fixed time, nothing missing on our side | Use SMS. Retest after approval (#61) |
| `stat .: permission denied` from `compose.sh` | `sudo -u deploy` was run from your home folder, which `deploy` can't read | Start the command with `cd /tmp &&` |

## 17. Verified

This table is for the end-to-end checks in section 9. They run after section 8. The **Verified** column records the date each row last passed, with no full phone number.

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | Setting on staging | Section 8, step 4 | `...AuthenticaSMSBackend True` | after iltiam-backend#103 | 2026-11-11 (backend `sha-8097a18`) |
| 2 | Super Admin sign-in | Section 9, check 1 | Code arrives from `Authentica` | after iltiam-backend#103 | 2026-11-12: from `Authentica`, Arabic template |
| 3 | New doctor, first password | Check 2 | Code arrives; the password is set | after iltiam-backend#127 and iltiam/iltiam-web#68 | 2026-11-12: Resend invite sent the SMS and the bilingual email with the `/set-password` link; the page said the account is active, the list showed Active, the doctor's dashboard opened (backend `sha-14223c2`, web `sha-5f1283f`) |
| 4 | Doctor sign-in on the web | Check 3 | Right code signs in; wrong code refused; a new code after 60 s | after iltiam/iltiam-web#68 | 2026-11-12: wrong code gave "code is not right"; after the countdown, "A new code is on its way by SMS" |
| 5 | Arabic and English | Check 4 | Templates 8 and 7 by the user's language; Arabic reads correctly | after iltiam-backend#103 | Arabic 2026-11-12. **English not tested** through the backend (the hourly limit was reached); template 7 itself passed on 2026-11-07 (section 6). Retest in #61 |
| 6 | Password reset | Check 5 | Code arrives; the new password works | after iltiam/iltiam-web#68 | 2026-11-12, by row 3: `/forgot-password` and `/set-password` are the same page with the same calls. A separate full run was stopped by the hourly limit (row 14) |
| 7 | New patient | Check 6 | Code arrives; the password is set | after iltiam-backend#103 | |
| 8 | Patient sign-in through the API | Check 7 | Right code signs in | after iltiam-backend#103 | |
| 9 | WhatsApp code | Check 8 | The code arrives and works | after Authentica approves the WhatsApp templates | **Fail 2026-11-12: blocked by Authentica/Meta template review** (HTTP 422, portal "WhatsApp: In review"; support: nothing missing on our side). Retest after approval (#61) |
| 10 | No codes in the logs | Check 9 | `0` | after iltiam-backend#103 | 2026-11-12: `0` over 3 hours (this pattern only matches the console backend, check 9) |
| 11 | Cost | Check 10 | Balance drop equals messages sent | after iltiam-backend#103 | 2026-11-12: 1 point per real SMS ("Paid, 1 pt" in **SMS → Logs**); balance 414 before the tests |
| 12 | Seeded account | A listed `+96659999xxxx` account signs in with `dev_otp_code` | The balance doesn't change | after iltiam-backend#104 | 2026-11-12: seeded numbers cost nothing |
| 13 | Mobile app, patient and doctor | The real app on staging | Code arrives and signs in | tracked on iltiam/iltiam-mobile#25 | |
| 14 | Hourly limit | 5 codes to one number in an hour, then sign-in and `/forgot-password` | Sign-in: "too many requests". Reset page: the neutral "If this number has an account…", and no SMS | after iltiam/iltiam-web#68 | 2026-11-12: both as expected (no account enumeration) |
| 15 | Unknown number | `/forgot-password` with a number that has no account | The same neutral answer, no SMS | after iltiam/iltiam-web#68 | 2026-11-12 |

**Record the results as a comment on issue #15:** pass or fail per row, with the date and a masked number. **Never include** a key, a code or a full phone number.

## 18. What comes next

- **#61:** WhatsApp codes once Authentica and Meta approve the templates (`AUTHENTICA_WHATSAPP_TEMPLATE_ID`, one id per language in the backend, Authentica's error text in the log, the web hides **Send by WhatsApp** until it works), and the English SMS retest (row 5).
- **Rows 7, 8 and 13:** the patient checks, with the mobile app (iltiam/iltiam-mobile#25).
- **#36:** production's application and API key, the sender name, and whether production gets a Commercial Registration or a separate account.
