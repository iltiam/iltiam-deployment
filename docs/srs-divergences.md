# SRS divergences

Decisions where ILTIAM differs from the SRS (`GP02_SRS_final.pdf`). Each one is recorded here once, so that it can
be copied into the SRS later. The AI service keeps its own list for the AI only (`docs/srs/divergences.md` in
iltiam-ai-service).

| ID | SRS | Topic | Status |
|---|---|---|---|
| [SD-01](#sd-01-patients-sign-in-with-a-password-and-a-code) | FR-P-1.1 | Patients sign in with a password and a code | Kept |
| [SD-02](#sd-02-the-mobile-app-has-no-captcha-yet) | FR-P-1.1 | The mobile app has no CAPTCHA yet | Until iltiam-mobile#63 |
| [SD-03](#sd-03-biometric-unlock-isnt-reachable-on-the-real-backend) | FR-P-1.1 | Biometric unlock isn't reachable on the real backend | Kept for v1.0 |

**Adding one:** the next free `SD-` number, and the same fields as below. Fill in the date and the person who
decided, and link where it was decided. Set **Status** to Kept, "Kept for <release>", or "Until <issue>" for one a
planned issue will remove. Never renumber: once a divergence is resolved, its status says so.

**Still to record** (iltiam-deployment#20): the doctor mobile app (Table 8), "wound not found" asking for a retake,
the per-request threshold for FR-D-5, Table 15 vs FR-CA-6, Cloudflare Tunnel instead of NGINX (§17), Authentica
instead of Twilio (§17), hosting (ADR-0004) and the iOS release moved to v1.1.

## SD-01: Patients sign in with a password and a code

- **SRS (FR-P-1.1, p. 36):** "primary login via phone number + OTP". The requirement's own inputs list a password
  too: "Phone number • Password • OTP (SMS or authenticator app)".
- **We do:** phone number and password first, then a 6-digit code (SMS, WhatsApp, email or the authenticator app),
  the same two steps as doctors and admins (FR-D-1). A patient who ticks "Remember this device" skips the code on
  that phone for 30 days, as FR-P-1.1 asks.
- **Why:**
  - one sign-in for every role, from one backend (iltiam-backend#16);
  - the password check comes first, so someone who only knows a phone number can't make the system send code SMS to
    it;
  - it follows the SRS's own list of inputs.
- **Decided by:** the project lead, in iltiam-mobile#25 ("keep password + code"), 2026-10-23.
- **SRS change:** FR-P-1.1's description should read "primary login via phone number + password, then an OTP".
- **Status:** Kept.

## SD-02: The mobile app has no CAPTCHA yet

- **SRS (FR-P-1.1, p. 36):** "CAPTCHA triggered after 3 failed attempts".
- **We do:**
  - **The backend:** after 3 failed sign-ins for a phone number within 10 minutes, it requires a Cloudflare
    Turnstile token from every client, mobile included. The web portal shows the widget.
  - **The mobile app (v1.0):** no widget. On `CAPTCHA_REQUIRED` it tells the user to wait 10 minutes and try again.
  - **The effect:** after 3 failed attempts, a mobile user can't try again for up to 10 minutes. The protection
    stays: the backend still refuses the sign-in.
- **Why:** Turnstile in the app needs a webview and a site key per build flavor, which is planned after the demo.
  The lead chose not to drop the CAPTCHA for mobile on the backend in the meantime.
- **Decided by:** the project lead, in the review of iltiam-mobile#25 (PR iltiam-mobile#62), 2026-11-09.
- **SRS change:** none once iltiam-mobile#63 lands. Until then, a note under FR-P-1.1 for the mobile app.
- **Status:** Until iltiam-mobile#63.

## SD-03: Biometric unlock isn't reachable on the real backend

- **SRS (FR-P-1.1, p. 36):** "biometric login (fingerprint / Face ID) available as a post-login shortcut only, not as
  a standalone factor", "supported on compatible devices".
- **We do:** the backend ends a session after 15 minutes without a request (NFR-SEC-02), and a token refresh doesn't
  count as activity. So on the real backend, the app's inactivity timer and a cold start after 15 idle minutes go to
  the sign-in screen (password and code), not to a fingerprint or Face ID lock screen. The biometric unlock works
  only with the mock backend used in development.
- **Why:**
  - a biometric unlock can't bring back a session the server has ended;
  - accepting a fingerprint alone at that point would make it a standalone factor, which FR-P-1.1 forbids;
  - the 15-minute timeout is enforced on the server for every client.
- **Decided by:** the project lead, in the review of iltiam-mobile#25 ("keep it as it is for v1.0"), 2026-11-09.
- **SRS change:** FR-P-1.1 should say that the biometric shortcut is not offered in v1.0, because sessions end
  server-side after 15 idle minutes.
- **Status:** Kept for v1.0. The rest of the sign-in security work is in iltiam-mobile#26.
