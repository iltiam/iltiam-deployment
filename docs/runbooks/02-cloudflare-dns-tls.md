# Runbook 2: Cloudflare account, DNS for iltiamcare.com, SSL/TLS, Turnstile and email records

- **Issue:** iltiam/iltiam-deployment#12 (DEP-01). **Decision record:** [ADR-0004](../adr/0004-hosting.md), Decisions 4 and 6.
- **Who:** anyone on the team with Administrator rights on the Cloudflare account. No cloud experience needed; follow the steps in order.
- **Time:** about 1.5 hours. DNSSEC then turns active by itself within 1–2 days. Two parts wait:
  - **HSTS** (section 7) waits for [Runbook 3](03-cloudflare-tunnels.md) (#9).
  - **The email provider** (sections 11.2 to 11.8) waits for the SMTP provider.
- **Result:** the zone `iltiamcare.com` on Cloudflare with:
  - two administrators with 2FA, and DNSSEC on;
  - Full (strict) TLS;
  - no response rewriting, and Bot Fight Mode off;
  - two Turnstile widgets;
  - a DMARC policy that blocks spoofing before we send any mail.

  The hostnames (`app.`, `api.`, `staging-app.`, `staging-api.`, `grafana.`, `status.`) are added later by [Runbook 3](03-cloudflare-tunnels.md) (#9) and the monitoring runbook (#10), not here.

> **This repository is public. Never paste a secret into this runbook, an issue, a PR, a commit or a chat.** That includes Turnstile secret keys, SMTP credentials, API tokens and 2FA recovery codes. Never write the Cloudflare account ID or zone ID either. **The dashboard's address bar contains the account ID, so never paste a dashboard URL.** The domain name itself is public and fine to write.

| Placeholder | Meaning |
|---|---|
| `<TEAMMATE_EMAIL>` | Email address of the second administrator (Omar-Nasri) |
| `<CF_DMARC_RUA>` | The report address Cloudflare DMARC Management creates (section 11.1) |
| `<DKIM_SELECTOR>`, `<OCI_DKIM_TARGET>` | DKIM record name and target that OCI shows (section 11.3) |
| `<OCI_SPF_INCLUDE>` | The SPF `include:` value that OCI shows for Riyadh (section 11.4) |
| `<OCI_RETURN_PATH_HOST>`, `<OCI_RETURN_PATH_TARGET>` | Custom return path CNAME that OCI shows (section 11.4) |
| `<SMTP_ENDPOINT>` | OCI Email Delivery's SMTP endpoint for Riyadh (section 11.2) |

Cloudflare redesigned its dashboard in 2025 and still moves menus. If a menu below is not where this says, type its name into the dashboard's search box.

## As built (2026-10-28)

| Item | Value |
|---|---|
| Domain | `iltiamcare.com` |
| Registrar | Cloudflare Registrar, registered 2026-10-28 |
| Account owner | ben-fatah |
| Owner 2FA | On |
| Second administrator | Omar-Nasri, Administrator (invited 2026-10-28) |
| Auto-renew | On |
| WHOIS privacy | On |
| Registrar lock | On |
| Nameservers | `karl.ns.cloudflare.com`, `keira.ns.cloudflare.com` |
| DNSSEC | Active (2026-10-28): DS record in `.com` (algorithm 13, digest type 2), answers validated |
| SSL/TLS encryption mode | Custom, Full (strict) |
| Edge certificates | Always Use HTTPS On, Minimum TLS 1.2, TLS 1.3 On, Automatic HTTPS Rewrites On |
| Universal SSL | Enabled; certificate status not yet Active |
| HSTS | Not yet (after #9, section 7) |
| Rocket Loader / Email Obfuscation (zone) | Off / Off |
| Configuration rule `api-no-rewrites` | Deployed: Email Obfuscation Off, Rocket Loader Off on `api.` and `staging-api.iltiamcare.com` |
| Bot Fight Mode | Off |
| Under Attack mode | Off |
| Turnstile widgets | `iltiam-staging` (`staging-app.iltiamcare.com`), `iltiam-prod` (`app.iltiamcare.com`); keys in both GitHub Environments |
| SPF / DMARC | `v=spf1 -all`; DMARC Management enabled, `_dmarc` with `p=quarantine` |
| SMTP provider | Pending (OCI Email Delivery, ADR-0004 Decision 6) |

## 1. Before you start

- The Cloudflare login that owns the account (ben-fatah's).
- An authenticator app on your phone.
- The teammate's email address (`<TEAMMATE_EMAIL>`).
- For section 10: admin rights on `iltiam/iltiam-deployment`, and the GitHub Environments `staging` and `production` from [Runbook 4](04-secrets.md), section 5. The GitHub CLI (`gh auth status` says "Logged in") is recommended.
- For the checks in section 12: PowerShell on Windows. `dig` is not in Git Bash; run `dig` lines on the VM (`ssh iltiam`, Runbook 1).

## 2. Protect the account: 2FA

1. Top-right profile icon → **My Profile → Authentication → Two-Factor Authentication.** Set it up with the authenticator app: scan the QR code, type the 6-digit code.
2. Save the **recovery codes** in your own password manager. They are a personal login secret. They don't go into this repository, and not into the ILTIAM escrow either (`docs/secrets.md`, section 5 holds only what GitHub can't).
3. Sign out and back in.

**What you should see:** the sign-in asks for the code, and **My Profile → Authentication** shows Two-Factor Authentication enabled.

## 3. A second administrator (Omar-Nasri)

1. Account home → **Manage Account → Members → Invite.**
   - Email: `<TEAMMATE_EMAIL>`.
   - Scope: the whole account (all domains).
   - Role: **Administrator.**
   - **Invite.**
2. The teammate accepts the invitation email and **turns on 2FA on their own profile the same day** (section 2, steps 1 and 2).
3. If the Members page offers a setting to **enforce two-factor authentication** for members, turn it on.

**What you should see:** **Members** lists ben-fatah as Super Administrator and Omar-Nasri as **Administrator**, with the invitation accepted. Ask Omar-Nasri to confirm that their **My Profile → Authentication** page shows 2FA enabled.

**What an Administrator can do:** everything in this runbook, but not manage members or billing. If the owner loses their phone, the recovery codes (section 2) get them back in; meanwhile the Administrator keeps the zone running.

## 4. Registrar: auto-renew, privacy, lock, DNSSEC

**Domain Registration → Manage Domains →** `iltiamcare.com` **→ Manage → Configuration.** Check each row:

| Setting | Value | Why |
|---|---|---|
| Auto-renew | **On** | An expired domain takes every hostname, the app and the API offline |
| WHOIS / contact privacy | **On** (redacted) | Keeps the owner's personal details out of public WHOIS |
| Registrar lock (transfer lock) | **On** | Stops the domain being transferred away |
| DNSSEC | **Enabled** | Resolvers can prove the answers really come from our zone |

Then **Manage Account → Billing → Payment info**: the card on file must still be valid on the renewal date (one year after registration).

**What you should see:** Auto-renew On, an expiry date one year after 2026-10-28, and DNSSEC enabled.

**DNSSEC shows "Pending" for 1–2 days.** That is normal for a new domain. Cloudflare publishes the signing keys, and the Registrar sends the DS record to the `.com` registry on its own. Check the status in **DNS → Settings → DNSSEC**, and with the commands in section 12.1. **Don't disable and re-enable it while it is pending**: that starts the wait again. Still pending after 3 days: section 13.

## 5. DNS records: what goes in now, and what doesn't

**Today the zone has only the email records of section 11.1.** Don't add A, AAAA or CNAME records for the hostnames below by hand. Runbook 3 creates them when it adds the tunnels' public hostnames, and a record you added first would clash with them.

| Hostname | What | Added by |
|---|---|---|
| `app.iltiamcare.com` | production web app | Runbook 3 (#9) |
| `api.iltiamcare.com` | production API; the mobile base URL is `https://api.iltiamcare.com/api` | Runbook 3 (#9) |
| `staging-app.iltiamcare.com` | staging web app | Runbook 3 (#9) |
| `staging-api.iltiamcare.com` | staging API | Runbook 3 (#9) |
| `grafana.iltiamcare.com` | monitoring, behind Cloudflare Access | Runbook 3 (#9) and #10 |
| `status.iltiamcare.com` | uptime page | #10 |

- **The AI service never gets a hostname.**
- **Hostnames stay one level deep** (`staging-api`, never `api.staging`). The free Universal certificate covers `iltiamcare.com` and `*.iltiamcare.com` only, and a wildcard covers one level.
- **Don't add CAA records.** Cloudflare picks the certificate authorities for the Universal certificate itself.

## 6. SSL/TLS

### 6.1 Encryption mode: Full (strict)

1. **SSL/TLS → Overview → Configure.**
2. Choose **Custom SSL/TLS** (new zones start on **Automatic SSL/TLS**, which may pick a weaker mode) → **Full (strict)** → **Save.**

**What you should see:** the Overview page shows **Full (strict)**.

Full (strict) means Cloudflare only talks to an origin over HTTPS with a valid certificate. The tunnel hostnames (Runbook 3) still work without any certificate on the VM: Cloudflare reaches them through the tunnel's own encrypted connection, not over the internet. Full (strict) protects any record that might ever point at a public address.

### 6.2 Edge certificates

**SSL/TLS → Edge Certificates.** Set:

| Setting | Value |
|---|---|
| Always Use HTTPS | **On** |
| HTTP Strict Transport Security (HSTS) | **Leave off for now** (section 7) |
| Minimum TLS Version | **TLS 1.2** |
| TLS 1.3 | **On** |
| Automatic HTTPS Rewrites | **On** |

TLS 1.3 is what browsers and phones use when they can (SRS §17). TLS 1.2 stays allowed for older Android devices.

**What you should see:** at the top of the page, a **Universal** certificate for `iltiamcare.com, *.iltiamcare.com`. Its status may stay **Pending** until Runbook 3 adds the first proxied hostname. That is fine.

## 7. HSTS: do this after Runbook 3 (#9)

> **Do after #9**, as part of [Runbook 3](03-cloudflare-tunnels.md), section 11.6. Only turn HSTS on when all of these hold:
> - `https://app.iltiamcare.com`, `https://staging-app.iltiamcare.com` and both API hosts open with no certificate warning;
> - every other subdomain that exists (`grafana.`, `status.`) also serves HTTPS.

Browsers remember HSTS for the whole max-age: **6 months**. With "include subdomains", any subdomain without HTTPS becomes unreachable for everyone who visited before, and switching HSTS off later doesn't help them.

1. **SSL/TLS → Edge Certificates → HTTP Strict Transport Security (HSTS) → Enable HSTS.** Read the warning → **I understand** → **Next.**
2. Set:
   - **Enable HSTS (Strict-Transport-Security):** On
   - **Max Age Header (max-age):** 6 months
   - **Apply HSTS policy to subdomains (includeSubDomains):** On
   - **Preload:** **Off** (the preload list is very hard to leave)
   - **No-Sniff Header:** On
3. **Save.**

**What you should see:**

```powershell
curl.exe -sI https://staging-app.iltiamcare.com/
```

The output includes `strict-transport-security: max-age=15552000; includeSubDomains`.

**The backend sends its own HSTS header** on the API hosts: one week, with subdomains (backend `docs/deployment.md`). Browsers obey the first header they get. After this step, run the same check against `https://staging-api.iltiamcare.com/api/health/`. Then set the Environment variable `SECURE_HSTS_SECONDS` to `15552000` in both GitHub Environments ([Runbook 4](04-secrets.md), section 9) and redeploy, so both headers say 6 months.

**From then on, never:**
- pause Cloudflare;
- switch a web hostname's record to **DNS only**;
- move the nameservers away;
- turn Always Use HTTPS off.

## 8. No response rewriting: Rocket Loader and Email Obfuscation off

Both features rewrite responses and inject inline scripts. On the API they could alter responses, and on the web app they would break its content security policy, which forbids inline scripts (iltiam/iltiam-web WEB-33). So they are **off for the whole zone**. A Configuration Rule keeps them off on the API hosts even if someone turns a zone toggle back on.

### 8.1 Zone-wide

1. **Speed → Optimization → Content Optimization → Rocket Loader:** **Off.**
2. **Email Obfuscation:** **Off.** In the new dashboard it is under **Security → Settings**; in the old one under **Scrape Shield**.

### 8.2 Configuration Rule for the API hosts

Configuration Rules are Cloudflare's current way to change settings per hostname. They replace the legacy Page Rules, and the Free plan allows 10.

1. **Rules → Configuration Rules → Create rule.** In the new dashboard: **Rules → Overview → Create rule → Configuration Rule.**
2. **Rule name:** `api-no-rewrites`.
3. **If incoming requests match… → Custom filter expression → Edit expression**, and paste:

   ```
   (http.host in {"api.iltiamcare.com" "staging-api.iltiamcare.com"})
   ```

4. **Then the settings are…:**
   - **+ Add → Email Obfuscation → Off.**
   - **+ Add → Rocket Loader → Off.**
5. **Deploy.**

**What you should see:** `api-no-rewrites` in the Configuration Rules list, enabled. The hostnames don't exist yet; the rule takes effect when Runbook 3 adds them.

## 9. Security settings

### 9.1 Bot Fight Mode: off

**Security → Settings**, filter **Bot traffic** → **Bot fight mode:** **Off.**

**Why off:**
- Cloudflare's documentation says it "may challenge API or mobile app traffic".
- It covers the whole zone, and on the Free plan it cannot be skipped for one hostname.
- Brute force on sign-in is handled instead by the rate-limiting rule on the sign-in paths ([Runbook 3](03-cloudflare-tunnels.md), section 7.1) and the backend's own lockout.

### 9.2 Security Level: nothing to set

DEP-01 asked for "Security Level: medium". **Cloudflare no longer has graded levels** ([Cloudflare docs](https://developers.cloudflare.com/waf/tools/security-level/), updated 2026-04-16):
- The threat score that "low / medium / high" were based on is now always 0.
- The old dashboard shows the level as **Always protected**, and it can't be changed.
- In the new dashboard, Security Level only turns **Under Attack mode** on or off.

So there is nothing to set. Check that **Security → Settings → Under Attack mode** is **Off**.

### 9.3 "Under Attack" mode: the manual DDoS switch

Cloudflare's always-on DDoS protection stops network floods by itself. Under Attack mode is for an **HTTP flood**, where requests look real:
- the web app is slow or unreachable, **and**
- **Security → Analytics** (or **Events**) shows a sudden flood of requests.

**What it does:** every visitor gets a challenge page before reaching the site. Browsers pass it after a few seconds. **The mobile app and the web app's API calls can't pass it.** They get an HTML challenge instead of JSON, so they stop working while it is on. That's why the switch is scoped to the web hosts.

**Turn it on for the web hosts only (preferred):**

1. **Rules → Configuration Rules → Create rule.**
   - Rule name: `under-attack-app`.
   - Expression:

     ```
     (http.host in {"app.iltiamcare.com" "staging-app.iltiamcare.com"})
     ```

   - Setting: **+ Add → I'm Under Attack → On.**
   - **Deploy.**
2. **Turn it off** as soon as the flood stops: switch the rule off in the list, or delete it.

You can create `under-attack-app` in advance and leave it **disabled**, so that turning it on is one click.

**Last resort (whole zone, API included; the mobile app stops working):** **Security → Settings → Under Attack mode → On.** Turn it off as soon as possible.

Either way, record when it was turned on and off, and why, in the incident record (DEP-09).

## 10. Turnstile widgets (CAPTCHA after 3 failed sign-ins)

One widget per environment. The backend checks the widget's **secret key**; the web app shows the widget with its public **site key**.

1. **Account home** (not inside the zone) → **Turnstile → Add widget.**
   - **Widget name:** `iltiam-staging`.
   - **Hostnames:** add `staging-app.iltiamcare.com`.
   - **Widget mode:** **Managed.**
   - Pre-clearance: **No.**
   - **Create.**
2. Cloudflare shows the **Site key** and the **Secret key**.
3. The site key is public, so it goes in an Environment **variable**:

   ```bash
   gh variable set TURNSTILE_SITE_KEY --env staging --body "<the site key>" -R iltiam/iltiam-deployment
   ```

4. The secret key goes in an Environment **secret**. Run this, paste the key at the prompt, then press Enter:

   ```bash
   gh secret set TURNSTILE_SECRET_KEY --env staging -R iltiam/iltiam-deployment
   ```

   Then `clear`.
5. Repeat steps 1 to 4 for production:
   - widget name `iltiam-prod`;
   - hostname `app.iltiamcare.com`;
   - `--env production` in both commands.

Without the GitHub CLI: **Settings → Environments → `<ENV>`**, add the variable and the secret by hand (Runbook 4, sections 6 and 9).

**What you should see:**
- **Turnstile** lists `iltiam-staging` and `iltiam-prod`, each with its one hostname.
- `gh secret list --env staging -R iltiam/iltiam-deployment` lists `TURNSTILE_SECRET_KEY`, and `gh variable list --env staging -R iltiam/iltiam-deployment` lists `TURNSTILE_SITE_KEY`. Check the same two for `production`.

Rotation and revocation: `docs/secrets.md`, section 2.

## 11. Email: SPF, DKIM and DMARC

The backend sends:
- invitations and activation links;
- sign-in codes by email (the fallback when an SMS doesn't arrive);
- breach notices (FR-P-7.1).

It sends from `no-reply@iltiamcare.com`, over SMTP on port 587 with STARTTLS. The provider is **OCI Email Delivery** in Riyadh ([ADR-0004](../adr/0004-hosting.md), Decision 6), with Resend as the fallback (section 11.8).

### 11.1 Today: "this domain sends no mail yet" (do now)

Until a provider is set up, nobody may send mail as `@iltiamcare.com`. Two records say so.

**SPF.** **DNS → Records → Add record:**

| Type | Name | Content | TTL |
|---|---|---|---|
| TXT | `@` | `v=spf1 -all` | Auto |

**Save.**

**DMARC, with reports through Cloudflare (free):**

1. **Email → DMARC Management → Enable DMARC Management.** Cloudflare adds a `_dmarc` TXT record with a report address of its own (`<CF_DMARC_RUA>`, ending in `dmarc-reports.cloudflare.net`).
2. **DNS → Records** → the `_dmarc` TXT record → **Edit.** Replace its content with the line below. Copy the report address **exactly as Cloudflare wrote it** in place of `<CF_DMARC_RUA>`. The content must **start with `v=DMARC1`, with nothing before it, not even a space**: receivers ignore a record that doesn't.

   ```
   v=DMARC1; p=quarantine; sp=quarantine; adkim=r; aspf=r; pct=100; fo=1; rua=mailto:<CF_DMARC_RUA>
   ```

3. **Save.**

| Part | Means |
|---|---|
| `p=quarantine`, `sp=quarantine` | Mail that fails the check goes to spam, for the domain and its subdomains |
| `adkim=r`, `aspf=r` | Relaxed alignment: a subdomain of `iltiamcare.com` counts as ours (needed for the return path) |
| `pct=100` | Applies to all mail |
| `fo=1` | Report a failure of either SPF or DKIM |
| `rua=…` | Daily summary reports go to Cloudflare, shown in **Email → DMARC Management** |

**Is DMARC safe before SPF and DKIM exist? Yes.** The domain sends nothing yet, so the policy can't catch any legitimate mail, and it stops anyone spoofing a new health brand from day one. **The one rule:** when the provider is set up, its DKIM must show **Active** before the first real email is sent (section 11.6). Otherwise invitations and codes land in spam.

**There is only ever one SPF record.** Section 11.4 *edits* this one; it never adds a second, because two SPF records make SPF fail everywhere.

**Don't add MX records.** Receiving mail (a `privacy@` inbox) is a separate follow-up.

**What you should see:**
- **DNS → Records** lists the TXT `iltiamcare.com` record `v=spf1 -all` and the TXT `_dmarc` record with `p=quarantine`.
- **Email → DMARC Management** shows the DMARC record as valid. Reports appear only once mail is sent.

### 11.2 Pending SMTP provider: check that Riyadh has Email Delivery (do this first)

> **Status: pending SMTP provider.** Sections 11.2 to 11.8 are not done yet. Until they are:
> - **staging** prints email to its log (Runbook 4, section 7);
> - **production** refuses to start, because the email settings are `prod-required`.

1. OCI console (Runbook 1). Region menu at the top: **Saudi Arabia Central (Riyadh).**
2. **☰ → Developer Services → Email Delivery → Configuration.**

**What you should see:** **SMTP sending information**, with a **Public endpoint**: that is `<SMTP_ENDPOINT>`. It should also show port **587** with STARTTLS.

**If Riyadh has no Email Delivery, or the page asks you to upgrade:** stop. Tell the owner, and use the fallback (section 11.8) only after the owner agrees. ADR-0004 Decision 6 changes then.

### 11.3 Pending SMTP provider: email domain and DKIM

1. **Email Delivery → Email Domains**, compartment `iltiam` → **Create Email Domain** → `iltiamcare.com` → **Create.**
2. Open `iltiamcare.com` → **DKIM → Add DKIM.**
   - **DKIM selector:** `iltiam-ruh-202611` (use the month you do this; if OCI asks for another format, follow its hint). This is `<DKIM_SELECTOR>`.
   - **Generate DKIM Record.** OCI shows a **CNAME record** name and value: `<OCI_DKIM_TARGET>`.
   - **Create DKIM.**
3. Cloudflare → **DNS → Records → Add record:**
   - **Type:** CNAME.
   - **Name:** only the part before `.iltiamcare.com`, i.e. `<DKIM_SELECTOR>._domainkey`. Cloudflare adds the domain itself.
   - **Target:** `<OCI_DKIM_TARGET>`.
   - **Proxy status: DNS only (grey cloud).** Cloudflare proxies new CNAMEs by default, and a proxied DKIM record never verifies.
   - **Save.**
4. Wait until the DKIM status in OCI turns **Active**. That takes minutes to a few hours.

### 11.4 Pending SMTP provider: approved sender, return path, SPF

1. **Email Delivery → Approved Senders**, compartment `iltiam` → **Create Approved Sender** → `no-reply@iltiamcare.com` → **Create.**
2. On the email domain page → **Custom return path** (or **Return path**) → **Add.** OCI shows a CNAME: `<OCI_RETURN_PATH_HOST>` → `<OCI_RETURN_PATH_TARGET>`. Add it in Cloudflare like the DKIM record, again **DNS only.**
3. OCI shows the SPF `include:` value for the region: `<OCI_SPF_INCLUDE>`. In Cloudflare, **edit** the existing `@` TXT record `v=spf1 -all` so that it reads:

   ```
   v=spf1 include:<OCI_SPF_INCLUDE> -all
   ```

**What you should see:** the approved sender `no-reply@iltiamcare.com`. After a refresh, the SPF and DKIM checks on the email domain page show as configured.

### 11.5 Pending SMTP provider: one SMTP user per environment

Staging and production never share a credential (Runbook 4, section 3). OCI ties SMTP credentials to a user, so there are two users.

1. **☰ → Identity & Security → Domains → Default domain → Groups → Create group:** `iltiam-smtp-senders`.
2. **User management → Create user:** `iltiam-smtp-staging`. If the form needs an email address, use a team address. Add it to `iltiam-smtp-senders`. Repeat for `iltiam-smtp-prod`.
3. **Identity & Security → Policies**, compartment `iltiam` → **Create Policy** `iltiam-smtp-send` with the statement:

   ```
   Allow group 'Default'/'iltiam-smtp-senders' to use approved-senders in compartment iltiam
   ```

4. Open `iltiam-smtp-staging` → **SMTP credentials → Generate credentials.**
   - Description: `iltiam-staging-<YYYY-MM>`.
   - OCI shows the **Username** and the **Password**. **The password is shown only once.** Keep this dialog open until step 6.
5. **Send a test email first, with these staging credentials** (section 11.6).
6. Send both values straight to GitHub. Run each command, paste the value at the prompt, then press Enter:

   ```bash
   gh secret set EMAIL_HOST_USER --env staging -R iltiam/iltiam-deployment
   gh secret set EMAIL_HOST_PASSWORD --env staging -R iltiam/iltiam-deployment
   ```

   Close the OCI dialog. Then `clear`.
7. Repeat steps 4 and 6 for `iltiam-smtp-prod` with `--env production`. No test send is needed for production.
8. Set the Environment variables in both environments ([Runbook 4](04-secrets.md), section 9):

   | Variable | staging | production |
   |---|---|---|
   | `EMAIL_BACKEND` | `django.core.mail.backends.smtp.EmailBackend` | same |
   | `EMAIL_HOST` | `<SMTP_ENDPOINT>` | same |
   | `EMAIL_PORT` | `587` | `587` |
   | `DEFAULT_FROM_EMAIL` | `ILTIAM Staging <no-reply@iltiamcare.com>` | `ILTIAM <no-reply@iltiamcare.com>` |

### 11.6 Pending SMTP provider: mail-tester score from the VM

This needs neither a deploy nor Runbook 3.

1. Open **mail-tester.com** in a browser and copy the one-time address it shows.
2. `ssh iltiam`, then create a small script. Nothing secret is typed on the command line:

   ```bash
   cat > ~/mailcheck.py <<'EOF'
   import getpass, smtplib
   from email.message import EmailMessage

   host = input("SMTP endpoint: ")
   user = getpass.getpass("SMTP username: ")
   password = getpass.getpass("SMTP password: ")
   to = input("mail-tester address: ")

   msg = EmailMessage()
   msg["From"] = "ILTIAM <no-reply@iltiamcare.com>"
   msg["To"] = to
   msg["Subject"] = "ILTIAM email check"
   msg.set_content("This is a delivery check for ILTIAM (Runbook 2, section 11.6).\n"
                   "No reply is needed.\n")

   with smtplib.SMTP(host, 587, timeout=30) as smtp:
       smtp.starttls()
       smtp.login(user, password)
       smtp.send_message(msg)
   print("sent")
   EOF
   python3 ~/mailcheck.py
   ```

3. Answer the four prompts. Paste the username and password from the open OCI dialog; they are not shown as you paste. The script prints `sent`.
4. Back on mail-tester → **Then check your score.**
5. Delete the script: `rm ~/mailcheck.py`.

**What you should see:** a score of **9/10 or more**, with SPF, DKIM and DMARC all passing in the "authenticated" section. Below 9: read that section first, then section 13.

### 11.7 Pending SMTP provider: go live

Only when all three hold:
- DKIM is **Active** in OCI;
- SPF was edited as in section 11.4;
- mail-tester scored 9 or more.

Then redeploy staging (Runbook 9). Check that a real email arrives in the inbox, not in spam: for example the first Super Admin's invitation (`bootstrap_superadmin`, backend `docs/deployment.md`).

Rotation and revocation of the SMTP credentials: `docs/secrets.md`, section 2.

### 11.8 Fallback: Resend

Use it only if Riyadh has no Email Delivery, or our tenancy can't send, **and** after the owner agrees.

Two things to know first:
- **Resend processes the mail outside the Kingdom.** Record the transfer in the PDPL records (DEP#6) before the first send, and update ADR-0004 Decision 6.
- **Free plan:** 3,000 emails a month, at most 100 a day, SMTP included ([Resend pricing](https://resend.com/pricing)).

**Steps:**

1. Sign up at resend.com, and turn on two-factor authentication in the account settings.
2. **Domains → Add domain** → `iltiamcare.com`. Resend shows a DKIM TXT record (`resend._domainkey`), and an MX and a TXT record on a `send` subdomain.
3. Add each record in Cloudflare exactly as shown, all **DNS only**. **Leave the `@` SPF record as `v=spf1 -all`**: Resend's SPF lives on `send.iltiamcare.com`.
4. **Verify DNS records.** Wait until the domain shows **Verified**.
5. **API Keys → Create API key,** one per environment, permission **Sending access**, limited to `iltiamcare.com`.
6. Fill in the GitHub Environments:
   - secret `EMAIL_HOST_USER` = `resend`;
   - secret `EMAIL_HOST_PASSWORD` = the environment's API key;
   - variable `EMAIL_HOST` = `smtp.resend.com`, `EMAIL_PORT` = `587`;
   - the rest as in the table in section 11.5, step 8.
7. Run the mail-tester check (section 11.6) with `smtp.resend.com`, then go live (section 11.7).

## 12. Verification checklist

### 12.1 Commands

Use Cloudflare's resolver (`1.1.1.1`) so an old answer cached by your provider doesn't mislead you.

**Windows (PowerShell):**

```powershell
Resolve-DnsName iltiamcare.com -Type NS -Server 1.1.1.1
Resolve-DnsName iltiamcare.com -Type DS -Server 1.1.1.1
Resolve-DnsName iltiamcare.com -Type SOA -Server 1.1.1.1 -DnssecOk
Resolve-DnsName iltiamcare.com -Type TXT -Server 1.1.1.1
Resolve-DnsName _dmarc.iltiamcare.com -Type TXT -Server 1.1.1.1
```

The same with `nslookup`, in PowerShell or cmd:

```
nslookup -type=NS iltiamcare.com 1.1.1.1
nslookup -type=DS iltiamcare.com 1.1.1.1
nslookup -type=TXT _dmarc.iltiamcare.com 1.1.1.1
```

**Linux, or on the VM (`ssh iltiam`):**

```bash
dig NS iltiamcare.com +short
dig DS iltiamcare.com +short
dig @1.1.1.1 iltiamcare.com SOA +dnssec
dig TXT iltiamcare.com +short
dig TXT _dmarc.iltiamcare.com +short
```

**If `Resolve-DnsName -Server 1.1.1.1` times out** (some networks block DNS port 53 to outside resolvers), ask Cloudflare's resolver over HTTPS instead. Paste this into PowerShell as one line:

```powershell
foreach ($q in @(@("iltiamcare.com","NS"),@("iltiamcare.com","TXT"),@("_dmarc.iltiamcare.com","TXT"),@("iltiamcare.com","DS"))) { $r = Invoke-RestMethod -Uri "https://cloudflare-dns.com/dns-query?name=$($q[0])&type=$($q[1])" -Headers @{accept="application/dns-json"}; "== $($q[0]) $($q[1])  DNSSEC-validated=$($r.AD)"; $r.Answer | ForEach-Object { $_.data } }
```

**What you should see:** four sections, each with `DNSSEC-validated=True`:
- **NS:** two names ending in `.ns.cloudflare.com.`
- **TXT:** `"v=spf1 -all"`
- **`_dmarc` TXT:** one line starting `"v=DMARC1; p=quarantine;`
- **DS:** one line starting with a key tag, then `13 2` (algorithm 13, digest type 2), then the digest

`DNSSEC-validated=True` is the resolver's AD flag: the answer was checked against the DNSSEC chain. **Don't paste the DMARC report address or the DS digest into the issue.**

**In a browser:**
- **DNSSEC chain:** `https://dnsviz.net/d/iltiamcare.com/dnssec/`
- **WHOIS:** `https://lookup.icann.org/en/lookup?name=iltiamcare.com`

### 12.2 Checklist

The **When** column says when a row can pass:
- **today**: now. DNSSEC (rows 6 to 8) can take 1–2 days on a new domain (section 4); ours was active on the day of registration;
- **after #9**: once Runbook 3's hostnames answer;
- **after SMTP provider**: once sections 11.2 to 11.7 are done.

The **Verified** column records the date each row last passed. "DoH" means the DNS-over-HTTPS check in section 12.1.

| # | Check | How | Expected | When | Verified |
|---|---|---|---|---|---|
| 1 | Owner 2FA | **My Profile → Authentication**; sign out and in | 2FA enabled; sign-in asks for the code | today | 2026-10-28 |
| 2 | Second administrator | **Manage Account → Members** | Omar-Nasri, **Administrator**, accepted; Omar-Nasri confirms 2FA on | today | Pending: invited 2026-10-28; acceptance and 2FA not yet confirmed |
| 3 | Registrar settings | **Manage Domains → iltiamcare.com → Configuration** | Auto-renew On, privacy On, lock On, DNSSEC enabled | today | 2026-10-28 |
| 4 | WHOIS | ICANN lookup (12.1) | Contact details redacted; status includes `clientTransferProhibited` | today | Pending: ICANN Lookup and Verisign RDAP timed out from our network (2026-10-28) |
| 5 | Nameservers | `Resolve-DnsName … -Type NS` / `dig NS` / DoH | Two names ending in `.ns.cloudflare.com` | today | 2026-10-28 (DoH) |
| 6 | DNSSEC in the dashboard | **DNS → Settings → DNSSEC** | Active (no longer Pending) | today | 2026-10-28 |
| 7 | DS record in `.com` | `Resolve-DnsName … -Type DS` / `dig DS` / DoH | One DS record, algorithm `13`, digest type `2`. Empty means still pending | today | 2026-10-28 (DoH) |
| 8 | DNSSEC validates | `Resolve-DnsName … -Type SOA -DnssecOk` / `dig @1.1.1.1 … +dnssec` / DoH; DNSViz | PowerShell lists an `RRSIG` record; `dig`'s `flags:` line contains `ad`; DoH prints `DNSSEC-validated=True`; DNSViz shows no errors | today | 2026-10-28 (DoH, AD true) |
| 9 | Encryption mode | **SSL/TLS → Overview** | Custom, **Full (strict)** | today | 2026-10-28 |
| 10 | Edge certificates | **SSL/TLS → Edge Certificates** | Always Use HTTPS On, Minimum TLS 1.2, TLS 1.3 On, Automatic HTTPS Rewrites On, HSTS off | today | 2026-10-28 |
| 11 | Universal certificate | **SSL/TLS → Edge Certificates** | Covers `iltiamcare.com, *.iltiamcare.com`; **Active** (may stay Pending until #9) | today / after #9 | Pending: Universal SSL enabled (2026-10-28); certificate not yet shown Active |
| 12 | Zone rewriting off | Rocket Loader and Email Obfuscation pages (8.1) | Both Off | today | 2026-10-28 |
| 13 | API rule | **Rules → Configuration Rules** | `api-no-rewrites` enabled: Email Obfuscation Off, Rocket Loader Off | today | 2026-10-28 |
| 14 | Bot Fight Mode | **Security → Settings → Bot traffic** | Off | today | 2026-10-28 |
| 15 | Under Attack | **Security → Settings** | Off; `under-attack-app`, if created, disabled | today | 2026-10-28 |
| 16 | Turnstile | **Turnstile**; `gh secret list` / `gh variable list` per environment | `iltiam-staging` and `iltiam-prod`; `TURNSTILE_SECRET_KEY` and `TURNSTILE_SITE_KEY` in both environments | today | 2026-10-28 |
| 17 | SPF, before the provider | `Resolve-DnsName iltiamcare.com -Type TXT` / `dig TXT` / DoH | Exactly one `v=spf1` record: `v=spf1 -all` | today | 2026-10-28 (DoH) |
| 18 | DMARC | `Resolve-DnsName _dmarc.iltiamcare.com -Type TXT` / `dig TXT _dmarc…` / DoH; **Email → DMARC Management** | Starts exactly with `v=DMARC1; p=quarantine; sp=quarantine; …; rua=mailto:…` (nothing before `v=`); shown as valid | today | 2026-10-28 (DoH) |
| 19 | HSTS | Section 7, `curl.exe -sI` on `staging-app` and `staging-api` | `max-age=15552000; includeSubDomains` on both | after #9 | |
| 20 | API not rewritten | `curl.exe -s https://staging-api.iltiamcare.com/api/health/` | The backend's JSON, unchanged; no `rocket-loader` or `email-decode` script anywhere | after #9 | |
| 21 | SSL Labs | `https://www.ssllabs.com/ssltest/analyze.html?d=staging-app.iltiamcare.com` | Grade **A** or better (A+ once HSTS is on) | after #9 | |
| 22 | DKIM | `Resolve-DnsName <DKIM_SELECTOR>._domainkey.iltiamcare.com -Type CNAME -Server 1.1.1.1` / `dig CNAME … +short`; OCI email domain | The OCI target; DKIM **Active** in OCI | after SMTP provider | |
| 23 | SPF with the provider | as row 17 | Exactly one `v=spf1` record, with `include:<OCI_SPF_INCLUDE>` | after SMTP provider | |
| 24 | mail-tester | Section 11.6 | **9/10 or more**; SPF, DKIM and DMARC pass | after SMTP provider | |
| 25 | A real email | An invitation from staging (section 11.7) | Arrives in the inbox, not in spam | after SMTP provider and #9 | |

**Record the results as a comment on issue #12:** pass or fail per row, with the date. **Never include** account IDs, zone IDs, dashboard URLs, keys, report addresses or email addresses.

## 13. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| DNSSEC still **Pending** after 3 days, and `dig DS` is empty | The Registrar hasn't pushed the DS record yet. Check **Manage Domains → Configuration**. Don't disable and re-enable it. Open a Cloudflare support ticket from the dashboard |
| `SERVFAIL` from `1.1.1.1` while other resolvers answer | DNSSEC validation fails: validating resolvers can't reach the domain. Look at DNSViz to see which key fails, then check **DNS → Settings → DNSSEC**. The DS record is managed by Cloudflare Registrar, so contact support; don't edit DNSSEC by hand |
| `Resolve-DnsName` shows an old answer, or none | Your resolver's cache. Use `-Server 1.1.1.1` or `-Server 8.8.8.8`, or wait for the TTL |
| `Resolve-DnsName -Server 1.1.1.1` times out | Your network blocks DNS port 53 to outside resolvers. Use the DNS-over-HTTPS check (section 12.1) |
| The `_dmarc` record shows spaces before `v=DMARC1` | Receivers ignore a DMARC record that doesn't start with `v=DMARC1`. **DNS → Records → `_dmarc` → Edit**, delete everything before `v=`, **Save**, and check again (section 12.1) |
| `dig: command not found` | Git Bash has no `dig`. Use PowerShell, or `ssh iltiam` (on the VM: `sudo apt install bind9-dnsutils` if it is missing) |
| Universal certificate still **Pending** a day after Runbook 3 | Check that no CAA record exists (section 5). Then open a Cloudflare support ticket |
| After Runbook 3: `ERR_TOO_MANY_REDIRECTS` | The encryption mode isn't Full (strict) (section 6.1), or the backend doesn't see `X-Forwarded-Proto: https` ([Runbook 3](03-cloudflare-tunnels.md), section 8) |
| The mobile app gets HTML instead of JSON, or `403` with a challenge page | Under Attack is on for the API hosts, or Bot Fight Mode is on. Sections 9.3 and 9.1 |
| The Configuration Rule's expression is refused | Straight double quotes `"`, hostnames separated by a space inside `{ }`, and the whole expression in parentheses |
| The teammate got no invitation | Spam folder. **Members** → remove the pending invitation and invite again |
| Turnstile shows "invalid domain" | The page's hostname isn't in the widget's **Hostnames** list (section 10) |
| mail-tester: SPF `permerror` | Two `v=spf1` records. Merge them into one (section 11.4) |
| OCI DKIM never turns Active | The CNAME is proxied (orange cloud): set **DNS only**. Or its name ends in `.iltiamcare.com.iltiamcare.com`: type only the part before the domain |
| `SMTPAuthenticationError` from `mailcheck.py` | Wrong username or password, or the user isn't in `iltiam-smtp-senders`, or the policy is missing (section 11.5) |
| `mailcheck.py` times out | Wrong endpoint or port: use `<SMTP_ENDPOINT>` from section 11.2, port 587 |
| mail-tester below 9/10 | Read its authentication section first. A failed DKIM means the email was sent before DKIM was Active |
| Real email lands in spam | DKIM not Active when it was sent, or the From address isn't the approved sender `no-reply@iltiamcare.com` |

## 14. Security notes

- **Accounts:** two administrators, both with 2FA. Recovery codes are personal and live in each person's own password manager.
- **No API tokens.** This runbook creates no Cloudflare API token. If a later runbook needs one, it gets the smallest scope and goes into a GitHub secret, never into the repository.
- **Never paste a dashboard URL.** It contains the account ID (Cloudflare) or OCIDs (OCI).
- **The domain:** DNSSEC on, registrar lock on, auto-renew on, WHOIS redacted.
- **Email:** DMARC `p=quarantine` from day one; the SMTP credentials are separate per environment.
- **PDPL:** Cloudflare decrypts TLS at its edge, outside the Kingdom. In-Kingdom-only decryption needs the paid Data Localization Suite ([ADR-0004](../adr/0004-hosting.md), Decision 4; recorded in DEP#6). Email through OCI Email Delivery is processed in Riyadh (Decision 6). The Resend fallback is not, and needs its DEP#6 record first.

## 15. What comes next

- **[Runbook 3](03-cloudflare-tunnels.md)** (#9): the tunnels, public hostnames, cache rules and the sign-in rate limit. Bot Fight Mode, Rocket Loader and Email Obfuscation are already set here, so #9 only verifies them. After #9:
  - section 7 (HSTS);
  - checklist rows 11 and 19 to 21.
- **SMTP provider:** sections 11.2 to 11.7, then checklist rows 22 to 25. These finish this issue.
- **Runbook 4** (#3): the Turnstile keys (section 10) and later the SMTP credentials (section 11.5) fill its sections 7 and 9.
- **Follow-up:** a `privacy@iltiamcare.com` inbox for breach-notice replies. It adds MX records and changes the SPF record, so it gets its own issue.
