# Patient result: "wound not found" asks for a retake and says the doctor will review

> **Plan ID:** BE-39 · **Owner:** Omar (@Omar-Nasri) · **Reviewer:** repo owner (@Omar-Nasri)
> **Milestone:** v1.0 · **Priority:** P0 · **Size:** S (≈1 day) · **Order:** #13 in Omar's list
> **Blocked by:** none
> **Blocks:** MOB-08
> **SRS:** FR-P-3.1; decision (owner): retake + doctor review

## Context

Today INSUFFICIENT/WOUND_NOT_FOUND maps to UNDER_REVIEW for the patient. Decision: ask the patient to retake AND say
the doctor will review. The tip for WOUND_NOT_FOUND already exists in patient_texts.py.

## Steps

- [ ] New state or flag: `RETAKE_NEEDED` with `doctor_will_review: true` for INSUFFICIENT with WOUND_NOT_FOUND (and WOUND_TOO_SMALL wording "too small to measure, your doctor will check").
- [ ] Bilingual headline; tips; notification RETAKE_REQUESTED.
- [ ] Update docs/api/patient-results.md.

## Acceptance criteria

- [ ] Patient sees retake tips plus the doctor-review sentence; doctor still sees MANUAL_REVIEW in attention list.

## Tests required

- patient_results tests for both reasons, AR/EN.

## Definition of done

- PR reviewed and approved by the repo owner; CI green; no secrets in code, logs or issue comments.
- User-facing text in Arabic and English (RTL checked) where the issue has UI.
- Docs/OpenAPI updated when behaviour or the contract changes; this issue linked from the PR.
