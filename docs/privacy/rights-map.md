# PDPL rights map

- **Issue:** #6. Each right → where the user uses it → the backend endpoint → the backend tests that prove it.
- **Tests** are in the private repository iltiam-backend, as `file::Class::test`. Each one was checked to exist on `main` on 2026-11-13. **NO TEST YET** means no backend test proves that part.
- **Screens:** patients use the Android app (Profile → Privacy). Staff use the web app. The texts the screens show are in [consent-texts.md](consent-texts.md) and [privacy-notice.md](privacy-notice.md); showing them is tracked in iltiam/iltiam-web#29 and iltiam/iltiam-mobile#44.
- **Response time:** the SRS gives 30 days for a deletion decision (FR-P-7.1). Whether that is the PDPL deadline for every right: **TO CONFIRM (TC-11).**
- **Sensitive actions** (export, withdrawing a consent, a deletion request) need a fresh identity check, a "step-up" code (backend issue #71).

## Summary

| # | Right | Patient screen | Staff screen | Tested |
|---|---|---|---|---|
| 1 | To be informed | privacy notice in the app (mobile#44) | privacy notice and staff policies on the web (web#29) | **NO TEST YET** |
| 2 | Access | Profile; Privacy → Access log | Settings (own account) | patients yes; staff **NO TEST YET** |
| 3 | Correction | Profile → edit | Settings (own account) | patients yes; staff **NO TEST YET** |
| 4 | A copy of the data (export) | Privacy → Export | — | yes |
| 5 | Withdraw consent | Privacy → consent switches | doctor records consent at registration | yes |
| 6 | Destruction (deletion, done as anonymisation) | Privacy → Delete my data | Super Admin: API only, **no web screen yet** | yes; staff deactivation yes |
| 7 | Breach notice within 72 hours | notification, SMS and email | Super Admin: API and `manage.py send_breach_notice`, **no web screen yet** | patients yes; regulator **NO TEST YET** |

## 1. To be informed

| Part | Where | Backend | Tests |
|---|---|---|---|
| Privacy notice `privacy-notice-v1` | app and web, before or at first sign-in | none: the text is in the apps | **NO TEST YET** (the apps' tests, in web#29 and mobile#44) |
| Staff policies `staff-policies-v1` accepted at activation | web activation | the activation and reset calls record `policies_accepted_at` and `policies_version` (setting `SYSTEM_POLICIES_VERSION`, today `2026-10`) | `apps/accounts/test_admins.py::ActivationTests::test_the_full_activation` (stores `policies_version` = `2026-10`) |

**Follow-up:** set `SYSTEM_POLICIES_VERSION` to `staff-policies-v1` when the web shows that text.

## 2. Access

| Part | Where | Endpoint | Tests |
|---|---|---|---|
| Own profile and medical background | app: Profile | `GET /api/patients/me/` | `apps/patients/test_profile.py::ProfileTests::test_reading_my_profile` |
| Who saw my data | app: Privacy → Access log | `GET /api/patients/me/access-log/` | `apps/patients/test_data_rights.py::ExportTests::test_the_access_log` |
| Everything, at once | app: Privacy → Export | `GET /api/patients/me/export/` (JSON or PDF) | `apps/patients/test_data_rights.py::ExportTests::test_json`, `::ExportTests::test_pdf_in_both_languages`, `::ExportTests::test_someone_elses_data_is_not_in_it` |
| Staff: own account | web: Settings | `GET /api/auth/me/` | **NO TEST YET** (sign-in tests call it, but none checks what it returns) |

## 3. Correction

| Part | Where | Endpoint | Tests |
|---|---|---|---|
| Patient's details and medical background | app: Profile → edit | `PATCH /api/patients/me/` | `apps/patients/test_profile.py::ProfileTests::test_updating_details_and_medical_background`, `::ProfileTests::test_field_rules` |
| Profile photo | app: Profile | `POST` and `DELETE /api/patients/me/photo/` | `apps/patients/test_profile.py::PhotoTests::test_replacing_and_removing_keep_the_old_files` |
| Clinical record | by the doctor, as a review or a new version; prescriptions are immutable | wound review and care plan endpoints | `apps/analysis/tests.py::OverrideTests` (doctor corrections of AI results) |
| Staff: own name and details | web: Settings | `PUT /api/auth/me/` | **NO TEST YET** (only the audit tests call it: `apps/core/tests.py::AuditWriteMiddlewareTests::test_a_write_without_its_own_event_is_recorded_once`) |

## 4. A copy of the data (export)

| Part | Where | Endpoint | Tests |
|---|---|---|---|
| Ask for an export (JSON or PDF, with or without photos) | app: Privacy → Export | `POST /api/patients/me/exports/` | `apps/patients/test_exports.py::RequestTests::test_a_request_queues_a_job`, `::RequestTests::test_without_step_up_it_is_refused`, `::RequestTests::test_one_at_a_time` |
| Built in the background, the patient is told | notification | Celery task | `apps/patients/test_exports.py::BuildTests::test_json_is_built_ready_for_seven_days`, `::BuildTests::test_photos_go_in_one_zip_with_the_data_file`, `::BuildTests::test_the_patient_is_told_and_it_is_audited` |
| Download, for 7 days | app: Privacy → Export | `GET /api/patients/me/exports/{id}/download/` (a 15-minute link) | `apps/patients/test_exports.py::DownloadTests::test_a_ready_job_gives_a_link_and_is_audited`, `::DownloadTests::test_an_expired_link_is_refused` |
| Only the patient's own | | `GET /api/patients/me/exports/` | `apps/patients/test_exports.py::RequestTests::test_the_list_and_detail_show_only_my_jobs`, `::RequestTests::test_other_roles_are_refused` |

## 5. Withdraw consent

Two consents ([consent-texts.md](consent-texts.md)): AI analysis (`ai-consent-v1`, recorded at registration) and the feedback dataset (`feedback-consent-v1`, off unless given). Withdrawing applies to future processing.

| Part | Where | Endpoint | Tests |
|---|---|---|---|
| Recorded at registration | web: the doctor's new patient form | `POST /api/patients/` | `apps/analysis/tests.py::ConsentTests::test_registering_a_patient_can_record_consent`, `::ConsentTests::test_consent_is_off_unless_recorded` |
| See and change | app: Privacy | `GET` and `PATCH /api/patients/me/consents/` | `apps/patients/test_data_rights.py::ConsentTests::test_defaults_and_changes_are_audited`, `apps/accounts/test_step_up.py::ProtectedActionTests::test_withdrawing_a_consent_needs_a_step_up` |
| AI analysis withdrawn: new photos are kept but not analysed | | upload and analysis queue | `apps/patients/test_data_rights.py::ConsentTests::test_a_new_photo_is_kept_but_not_analysed`, `::ConsentTests::test_waiting_analyses_are_skipped_finished_ones_stay`, `::ConsentTests::test_the_queue_checks_consent_too` |
| Feedback withdrawn: corrections leave the dataset | | `manage.py export_feedback_dataset` | `apps/patients/test_data_rights.py::ConsentTests::test_training_consent_removes_corrections_from_the_dataset`, `apps/analysis/tests.py::ConsentTests::test_consent_is_snapshotted_and_withdrawal_leaves_the_dataset`, `apps/analysis/test_feedback_export.py::FeedbackExportTests::test_withdrawn_consent_anonymised_patients_and_deletion_requests_are_left_out` |

## 6. Destruction (deletion, done as anonymisation)

A patient's approved request **anonymises** them (iltiam-backend `apps/patients/data_rights.py`, `anonymize`): the name, phone number, email, last sign-in IP, date of birth, gender, medical background and profile photo are removed; the password stops working; both consents are turned off; sessions, trusted devices and push tokens are ended; their notifications, and any that name them, are deleted; open appointments are cancelled. The clinical record stays, without them, for medical-record retention. **What stays:** wound photos, notes and message text, which may still identify the person (a face, a tattoo, a name typed in a message). Whether this satisfies the right: **TO CONFIRM (TC-12).** Decided within 30 days (FR-P-7.1).

| Part | Where | Endpoint | Tests |
|---|---|---|---|
| Ask | app: Privacy → Delete my data | `POST /api/patients/me/deletion-request/` | `apps/patients/test_data_rights.py::DeletionRequestTests::test_a_request_is_logged_and_everyone_told` |
| Withdraw the request while pending | app: Privacy → Delete my data | `POST /api/patients/me/deletion-request/cancel/` | `apps/patients/test_data_rights.py::DeletionRequestTests::test_a_pending_request_can_be_cancelled_and_leaves_the_queue`, `::DeletionRequestTests::test_a_decided_request_cannot_be_cancelled` |
| Super Admin decides | **no web screen yet**: the API | `GET /api/data-requests/`, `POST /api/data-requests/{id}/approve/`, `POST /api/data-requests/{id}/reject/` | `apps/patients/test_data_rights.py::DeletionRequestTests::test_the_super_admins_list`, `::DeletionRequestTests::test_approval_anonymizes_and_keeps_the_clinical_record`, `::DeletionRequestTests::test_rejection` |
| The 30-day deadline | reminder to Super Admins | reminder rule | `apps/patients/test_data_rights.py::DeletionRequestTests::test_the_deadline_reminder` |
| Operational data past its period | none | `manage.py run_retention` ([retention.md](retention.md)) | `apps/core/test_retention.py::RunTests::test_enforcing_deletes_exactly_what_is_due`, `::RunTests::test_the_audit_logs_and_clinical_records_are_never_touched` |
| **Doctors: never deleted, only deactivated** (medical data integrity, **TO CONFIRM, TC-17**) | web: Clinic Admin's doctor list → Deactivate | `POST /api/clinic/doctors/{id}/status/`; Super Admin `POST /api/clinics/{id}/doctors/{doctor_id}/status/` | `apps/clinics/tests.py::DoctorStatusTests::test_deactivating_keeps_the_patients_and_ends_the_session`, `apps/clinics/tests.py::SuperAdminDoctorLifecycleTests::test_soft_delete_hides_the_doctor_keeps_patients_and_audit_and_blocks_login` |

## 7. Breach notice within 72 hours

The 72-hour deadline and who must be told: **TO CONFIRM (TC-7).** The incident response runbook is #21.

| Part | Where | Endpoint or command | Tests |
|---|---|---|---|
| Record the incident; the 72-hour countdown | **no web screen yet**: the API | `POST /api/breach-incidents/` | `apps/notifications/test_breach.py::RecordTests::test_recording_audits_and_shows_the_72_hour_countdown` |
| Tell affected patients, in their language, by in-app notification, push, SMS and email | the patient's inbox, phone and mailbox | `POST /api/breach-incidents/{id}/notify/` | `apps/notifications/test_breach.py::NotifyTests::test_fan_out_in_each_patients_language_with_delivery_tracked`, `::NotifyTests::test_repeating_reaches_only_patients_not_yet_notified`, `::NotifyTests::test_anonymized_patients_are_never_contacted` |
| The same, from the command line | VM | `manage.py send_breach_notice` | `apps/notifications/test_emails.py::BreachNoticeTests::test_every_patient_by_email_and_sms`, `::BreachNoticeTests::test_running_it_again_notifies_nobody_twice` |
| The record of who was told | Super Admin | `GET /api/breach-incidents/{id}/notices/export/` (CSV) | `apps/notifications/test_breach.py::ExportTests::test_the_notification_record_exports_as_csv_and_is_audited` |
| **Tell the regulator (SDAIA)** | **manual**, by the controller (TC-1), per #21 | none | **NO TEST YET** (a manual process) |

## Gaps

- **NO TEST YET:** right 1 (the texts are shown by the apps); staff access (`GET /api/auth/me/`) and staff correction (`PUT /api/auth/me/`) as rights; the notice to the regulator (manual).
- **No web screen yet** for Super Admins: deletion requests and breach incidents (API only). Suggested for iltiam/iltiam-web#29 or a new web issue.
- The consent version ID isn't stored ([consent-texts.md](consent-texts.md), "Recording").
