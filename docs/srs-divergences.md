# SRS divergences

Decisions where ILTIAM differs from the SRS (`GP02_SRS_final.pdf`). Each one is recorded here once, so that it can
be copied into the SRS later. The AI service keeps its own list for the AI only (`docs/srs/divergences.md` in
iltiam-ai-service).

| ID | SRS | Topic | Status |
|---|---|---|---|
| [SD-01](#sd-01-patients-sign-in-with-a-password-and-a-code) | FR-P-1.1 | Patients sign in with a password and a code | Kept |
| [SD-02](#sd-02-the-mobile-app-has-no-captcha-yet) | FR-P-1.1 | The mobile app has no CAPTCHA yet | Until iltiam-mobile#63 |
| [SD-03](#sd-03-biometric-unlock-isnt-reachable-on-the-real-backend) | FR-P-1.1 | Biometric unlock isn't reachable on the real backend | Kept for v1.0 |
| [SD-04](#sd-04-doctors-also-use-the-mobile-app) | Table 8, FR-D-1 | Doctors also use the mobile app | Kept |
| [SD-05](#sd-05-no-wound-found-asks-the-patient-for-a-new-photo-and-says-the-doctor-will-review) | FR-P-3.1 | "No wound found" asks for a new photo; the doctor reviews | Kept |
| [SD-06](#sd-06-the-ai-service-takes-the-manual-review-threshold-with-each-request) | FR-D-5 | The AI service takes the review threshold with each request | Kept |
| [SD-07](#sd-07-clinic-admins-deactivate-doctors-archive-and-soft-delete-are-the-super-admins) | FR-CA-6, Table 15 | Clinic Admins deactivate; archive and soft delete are the Super Admin's | Kept |
| [SD-08](#sd-08-cloudflare-tunnel-instead-of-an-nginx-reverse-proxy) | §17.1 | Cloudflare Tunnel instead of an NGINX reverse proxy | Kept |
| [SD-09](#sd-09-authentica-instead-of-twilio-for-sms) | §17.1 | Authentica instead of Twilio for SMS | Kept |
| [SD-10](#sd-10-hosting-on-one-oracle-cloud-vm-in-riyadh-with-oci-object-storage) | §17 | Hosting on one Oracle Cloud VM in Riyadh | Kept |
| [SD-11](#sd-11-the-ios-release-moves-to-v11) | §14, §17.1 | The iOS release moves to v1.1 | Until v1.1 |

**Adding one:** the next free `SD-` number, and the same fields as below. Fill in the date and the person who
decided, and link where it was decided. Set **Status** to Kept, "Kept for <release>", or "Until <issue>" for one a
planned issue will remove. Never renumber: once a divergence is resolved, its status says so.

**Where it's linked from:** every repository's README, and iltiam-ai-service's `docs/srs/divergences.md` (which
keeps the AI-only rows). Rows marked **To confirm in review** name where a decision was proposed but not who agreed;
the owners fill that in when they review (iltiam-deployment#20).

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

## SD-04: Doctors also use the mobile app

- **SRS (Table 8; FR-D-1; §14.3):** the doctor is a web user ("Doctor = Web"; FR-D-1 "authenticate into the web
  dashboard"). The mobile app is the patient app, with no doctor requirement or mockup.
- **We do:** the patient app also has a doctor role behind its own `/doctor` screens: worklist, patient list and
  register, capture/upload for a patient, AI result, review, alerts and messages, on the same backend API as the web.
  The web dashboard stays the doctor's full tool (SOAP notes, prescriptions, care plans).
- **Why:** doctors capture wound photos at the bedside with a phone; the same backend rules and RBAC apply to both
  clients, so nothing new is allowed.
- **Decided by:** proposed in iltiam-mobile#16 (`issues/issue-16/spec.md`, decision D1: "same app, role-based"). The
  review asks for the team's agreement. **To confirm in review:** who agreed, and the date.
- **SRS change:** add the doctor as a mobile actor in Table 8 and a doctor mobile section to §14.
- **Status:** Kept.

## SD-05: "No wound found" asks the patient for a new photo and says the doctor will review

- **SRS (FR-P-3.1):** the patient sees their result once the analysis is done; it doesn't describe a photo in which
  the AI finds no wound.
- **We do:** when the AI finds no wound (`WOUND_NOT_FOUND`) or a wound too small to measure, the patient is asked for
  a new photo **and** told that their doctor will look at this one (`RETAKE_NEEDED` with `doctor_will_review`). The
  doctor gets it as MANUAL_REVIEW. Before, the patient saw "under review" only.
- **Why:** the patient can act at once (a new photo usually fixes it), and a real wound the AI missed still reaches
  the doctor.
- **Decided by:** the backend owner, in iltiam-backend#68 (`docs/issues/issue-68/intent.md`: "the owner's decision:
  retake and doctor review"), 2026-10-24.
- **SRS change:** FR-P-3.1 should add the "no wound found" result: retake, and the doctor reviews.
- **Status:** Kept.

## SD-06: The AI service takes the manual-review threshold with each request

- **SRS (FR-D-5):** the Super Admin changes the confidence threshold; a change needs an OTP, is audited with the old
  and new values, triggers a re-evaluation report within 24 hours, and shows a system-wide notice.
- **We do:** the threshold lives in the backend, which governs every change (step-up code: iltiam-backend#71;
  the change itself: iltiam-backend#77), and sends the active value with each analysis. The AI service stays
  stateless: it applies the value it gets and echoes it in `decision.manual_review_threshold`
  (`manual_review_threshold_source`: `REQUEST`), or uses the model's own value when none is sent
  (iltiam-ai-service#146). The re-evaluation report is iltiam-ai-service#148.
- **Why:** one place holds governed settings, with the audit log and the OTP, and the AI service keeps no state
  between requests, so it can be scaled or replaced without losing a setting.
- **Decided by:** the plan (iltiam-ai-service#146, AI-02; iltiam-backend#77, BE-11a). **To confirm in review:** who
  decided, and the date.
- **SRS change:** FR-D-5 should say where the threshold is stored (the backend) and that the AI service receives it
  with each request.
- **Status:** Kept. Built in iltiam-ai-service#146; the backend side lands with iltiam-backend#77.

## SD-07: Clinic Admins deactivate doctors; archive and soft delete are the Super Admin's

- **SRS:** FR-CA-6 lets the Clinic Admin deactivate or archive a doctor. Table 15 (the RBAC matrix) gives "Archive
  Doctor" and "Soft Delete Doctor (logical)" to the Super Admin only, and "Deactivate" to both.
- **We do:** Table 15. A Clinic Admin deactivates a doctor of their clinic and can reactivate one they deactivated;
  archiving, unarchiving and the logical delete are Super Admin actions (iltiam-backend#75).
- **Why:** Table 15 is the SRS's authoritative access matrix, and the two texts can't both hold.
- **Decided by:** the issue's own instruction (iltiam-backend#75: "Clinic Admin limited to deactivate (Table 15);
  record the FR-CA-6 vs Table 15 inconsistency"). **To confirm in review:** the reading for reactivation (a Clinic
  Admin may undo their own deactivation).
- **SRS change:** FR-CA-6 should drop "archive" for the Clinic Admin, to match Table 15.
- **Status:** Kept, from iltiam-backend#75.

## SD-08: Cloudflare Tunnel instead of an NGINX reverse proxy

- **SRS (§17.1, item 4):** "an NGINX instance that serves the compiled React static assets and acts as a reverse
  proxy … Handles TLS termination."
- **We do:** Cloudflare (DNS, TLS, DDoS) reaches the VM only through Cloudflare Tunnel; no inbound web port is open
  and there are no certificates on the VM. nginx still serves the React files inside the web image, without TLS.
- **Why:** no open ports, no certificate renewal, one container, and free ([ADR-0004](adr/0004-hosting.md),
  Decision 4).
- **Decided by:** ben-fatah and Omar-Nasri, ADR-0004 (accepted 2026-10-27; Decision 4 updated 2026-10-28).
- **SRS change:** §17.1 item 4 should describe the tunnel and say TLS ends at Cloudflare.
- **Status:** Kept.

## SD-09: Authentica instead of Twilio for SMS

- **SRS (§17.1, item 10; and the notification module):** "Twilio (SMS): External SMS gateway. Delivers OTP codes …
  and high-risk deterioration alerts".
- **We do:** Authentica, a Saudi provider, sends the sign-in and password codes (SMS, WhatsApp) and the SMS
  notifications. Twilio's code stays in the backend as a pluggable option, unconfigured.
- **Why:** Saudi sender registration and local delivery, and cost ([ADR-0004](adr/0004-hosting.md), Decision 5).
- **Decided by:** ben-fatah and Omar-Nasri, ADR-0004 (2026-10-23).
- **SRS change:** §17.1 item 10 and the notification module should name Authentica.
- **Status:** Kept.

## SD-10: Hosting on one Oracle Cloud VM in Riyadh, with OCI Object Storage

- **SRS (§17):** a deployment of separate web server, application server, database, Redis and object storage
  ("AWS S3 or MinIO"), with no provider named for the servers.
- **We do:** everything runs as containers on one Oracle Cloud Always Free ARM VM in the Riyadh region (staging and
  production as two Compose projects), with OCI Object Storage (S3-compatible) for files. The AI service is its own
  container, not part of the application server.
- **Why:** data stays in Saudi Arabia (PDPL), it costs nothing, and the ARM VM was measured to be fast enough for the
  AI ([ADR-0004](adr/0004-hosting.md), Decisions 1–3).
- **Decided by:** ben-fatah and Omar-Nasri, ADR-0004 (accepted 2026-10-27).
- **SRS change:** §17 should name the provider and region, and show the AI service as its own container.
- **Status:** Kept.

## SD-11: The iOS release moves to v1.1

- **SRS (§14, §17.1 item 1; compatibility):** the patient app runs on Android 10+ **and iOS 14+**.
- **We do:** v1.0 (due 2026-11-30) ships Android only. The iOS build, TestFlight, push and App Store work are in the
  v1.1 milestone (iltiam-mobile#56, #57, #58).
- **Why:** the team's time before 2026-11-30, and the Apple account and devices iOS needs
  ([plan](planning/plan.md): "Milestone v1.1 holds the iOS / App Store work").
- **Decided by:** the release plan (`docs/planning/plan.md`). **To confirm in review:** who decided, and the date.
- **SRS change:** the compatibility rows should say iOS comes in v1.1.
- **Status:** Until v1.1.
