# Store publishing checklist (Google Play and App Store)

Everything needed before the ILTIAM app is submitted (issue #68). The console work is done by hand by Thabit; nothing
here is submitted automatically. Related: the [go-live checklist](../go-live-checklist.md) (#23), the production
environment (#36), the privacy documents in [`docs/privacy/`](../privacy/index.md) (#6), and the draft
[store listing texts](listing-texts.md).

Ticking this list does not make ILTIAM legally approved, clinically validated or ready for real patients. Copy it
into a comment on #68 and tick each item with its evidence (a screenshot, a link, a date).

**Order:** Android first (v1.0). iOS is v1.1 ([SRS divergences](../srs-divergences.md), SD-11): the App Store part
is prepared here so the decisions it needs (a legal entity) start early.

## 1. Decisions that take time (start now)

- [ ] **Google Play account type.** A new **personal** account must run a **closed test with at least 12 testers for
      14 days in a row** before it may publish to production. An **organisation** account avoids that and needs a
      **D-U-N-S number** (free, takes days to weeks). Decide, and plan the calendar: a personal account needs the 14
      days to finish before the launch date of #23.
- [ ] **Apple developer account and legal entity.** App Store Review Guideline **5.1.1(ix)**: apps in highly
      regulated fields such as healthcare must be submitted by a **legal entity** that provides the service, not an
      individual. Decide which entity (a clinic, a company, the university) owns the account.
- [ ] **Medical device question.** ILTIAM measures wounds with AI and shows risk to doctors. Whether that makes it
      software as a medical device for the Saudi Food and Drug Authority (SFDA), and which listing claims are allowed,
      is a legal question to answer with the legal review of #23 (`docs/privacy/index.md`). Until then the listing
      makes **no diagnosis or treatment claims** ([listing texts](listing-texts.md), rules).

## 2. Web pages (must be live: iltiam/iltiam-web#70)

- [ ] Privacy policy: `https://iltiamcare.com/privacy` (`privacy-notice-v1`), public, Arabic and English, tested from
      a phone without signing in.
- [ ] Terms: `https://iltiamcare.com/terms` (`terms-v1`).
- [ ] Account deletion: `https://iltiamcare.com/delete-account`, with a working way to request deletion **without
      the app**, and the explanation that the medical record is kept without identity.
- [ ] Support contact: `privacy@iltiamcare.com` answers (the team mailbox, Runbook 2, section 11).

## 3. The app build

- [ ] **App icon** replaces Flutter's default: Android adaptive icon (foreground and background), all densities;
      the Play listing icon 512 × 512 PNG; later the iOS set and 1024 × 1024 App Store icon.
- [ ] **Production flavor** (`--flavor prod`): `com.iltiamcare.app`, `API_BASE_URL=https://api.iltiamcare.com`,
      `MOCK_BACKEND=false`, no demo mode (the startup guard refuses the rest; iltiam-mobile#23).
- [ ] **Version** set for the release (pubspec `version:`; Play needs a higher `versionCode` for every upload).
- [ ] **Release signing:** upload key in the team's escrow (Bitwarden, [secrets](../secrets.md)), **Play App
      Signing** on (Google keeps the app signing key). Never commit the keystore or `key.properties`.
- [ ] **Android App Bundle** (`flutter build appbundle --flavor prod ...`) built from a commit whose
      `scripts/ci-local.sh --full` passed in iltiam-mobile.
- [ ] **Target API level** at or above what Play requires on the upload date (Play Console shows it).
- [ ] Blockers done (also on #23): iltiam/iltiam-mobile#77 (bundled fonts, nothing to Google Fonts),
      iltiam/iltiam-mobile#76 (no unused media permissions), iltiam/iltiam-mobile#44 (the app shows
      `privacy-notice-v1`, `terms-v1` and the consents, and records acceptance), iltiam/iltiam-backend#128 (no health
      data in push text), iltiam/iltiam-backend#129 (deletion does what the notice says), `RETENTION_ENFORCE` on in
      production (#66, #36) and the export clean-up rule (#65).
- [ ] The production backend runs and accepts real sign-ins (#36, #23): reviewers sign in against it.

## 4. Google Play Console

Under **Play Console → your app**:

- [ ] **Store listing** (Grow → Store presence → Main store listing): name, short and full description in Arabic and
      English from [listing texts](listing-texts.md); icon; feature graphic 1024 × 500; at least 2 phone screenshots
      per language (section 6); category **Medical**; contact email `privacy@iltiamcare.com`; privacy policy URL.
- [ ] **App content → Privacy policy:** `https://iltiamcare.com/privacy`.
- [ ] **App content → Data safety:** exactly the answers of [Play data safety](../privacy/play-data-safety.md).
- [ ] **App content → Health apps:** declare the health features: tracking a medical condition (wound healing),
      communication with clinicians, and the measurement of wound photos used by clinicians. State that results are
      reviewed by the patient's doctor and are not a diagnosis.
- [ ] **App content → Account deletion:** in the app, Profile → Privacy → Delete my data; on the web, the
      `/delete-account` URL.
- [ ] **App content → App access:** "All or some functionality is restricted": give the reviewers the demo account
      of section 5 and how to sign in.
- [ ] **App content → Ads:** no ads.
- [ ] **App content → Target audience:** 18 and over (patients under 18 only through a parent or guardian, `terms-v1`);
      not designed for children.
- [ ] **App content → Content rating:** the questionnaire (category: reference, health or medical; no violence, no
      user-generated public content, messages only between a patient and the care team). Expected: rated for everyone.
- [ ] **App content → Government apps, financial features, news:** no.
- [ ] **Testing → Closed testing** (personal account: 12 or more testers who stay opted in for 14 days in a row), then
      **Apply for production access** with the answers about the test.
- [ ] **Production → Create release:** the App Bundle, release notes from [listing texts](listing-texts.md), rollout to
      100 % (or staged, 20 % first).

## 5. The reviewers' account

- [ ] A **production** test patient and a test doctor in a test clinic, created by the Super Admin, holding no real
      data. Their passwords in Bitwarden, given to the reviewers only in the console's App access field.
- [ ] Sign-in codes: production sends real SMS. Give the reviewers a way to get the code (a test phone number the
      team owns and reads, or the authenticator option), and write it in the review notes.
- [ ] After the review: change those passwords; archive the accounts when no review needs them.

## 6. Screenshots and graphics

From the production build on a real phone, Arabic and English each, with the test accounts (never real patient
data, never a real name, phone number or photo of a real wound; use the printed demo wound sheets):

1. The patient's home: next steps and reminders.
2. Taking a photo with the measuring marker (the guide on the camera).
3. A reviewed result with the healing chart.
4. Messages with the care team.
5. Appointments.
6. Privacy: the data and deletion screen.

Feature graphic 1024 × 500: the ILTIAM logo, the tagline from the listing texts, no medical claim, no photo of a real
wound.

## 7. App Store (iOS, v1.1)

- [ ] The legal entity's Apple developer account (section 1).
- [ ] **App privacy** ("nutrition labels") from the same data as [Play data safety](../privacy/play-data-safety.md):
      Health and fitness, Contact info, Identifiers, Photos, User content (messages); used for app functionality;
      linked to the user; not used for tracking.
- [ ] **In-app account deletion** (Guideline 5.1.1(v)): Profile → Privacy → Delete my data starts it in the app.
      Explain in the review notes that a request is reviewed within 30 days and anonymises the record, because
      medical records must be kept, and link the `/delete-account` page.
- [ ] **Health claims** (Guideline 1.4.1): no claim of diagnosis or of measuring accuracy beyond what is validated;
      the measurement is a clinician's aid.
- [ ] Review notes and the reviewers' account of section 5.
- [ ] Subtitle, promotional text, keywords and screenshots (6.7-inch and 5.5-inch) from [listing texts](listing-texts.md).

## 8. Evidence for #68

Link here, in the #68 comment, for each store: the console screenshot of each completed App content form, the
store listing in both languages, the test results of the deletion flow (in app and on the web), and the reviewers'
account test (signed in from a clean phone).
