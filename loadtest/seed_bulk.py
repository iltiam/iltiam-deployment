"""Bulk metadata for the load test (issue #22): 500 patients and 60,000 image records.

Run by scripts/loadtest.sh inside the backend container, AFTER `manage.py seed_load_test` (iltiam-backend), which
creates the load-test clinic: 50 doctors, 500 patients, 4,000 analysed visits. This adds completed visits (metadata
only, no photo files) to each patient's HEEL wound until the database holds TARGET visits in total, spread over the
last two years, so lists, the dashboard and progression run against production-sized tables.

Local stack only: it refuses to run unless the load-test clinic exists and the environment is not production.
Safe to run twice: it only adds what is missing.
"""
import random
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import connection, transaction
from django.utils import timezone

from apps.clinics.models import Clinic
from apps.patients.models import Patient
from apps.wounds.models import Visit, Wound, WoundAssessment

TARGET = 60_000
BATCH = 2_000
CLINIC_NAME = 'Load Test Clinic'

assert settings.ENVIRONMENT != 'production', 'never on production'
clinic = Clinic.objects.get(name=CLINIC_NAME)
patients = list(Patient.objects.filter(clinic=clinic).select_related('assigned_doctor').order_by('user__phone_number'))
assert len(patients) == 500, f'expected the 500 load-test patients, found {len(patients)}'

missing = TARGET - Visit.all_objects.count()
print(f'visits now: {TARGET - missing}; adding {max(missing, 0)}')
rng = random.Random(22)
now = timezone.now()
heel = {w.patient_id: w for w in Wound.objects.filter(patient_id__in=[p.pk for p in patients],
                                                       location=Wound.AnatomicalLocation.HEEL)}
added = 0
while added < missing:
    visits, assessments = [], []
    for _ in range(min(BATCH, missing - added)):
        patient = patients[added % len(patients)]
        wound = heel[patient.pk]
        visit = Visit(wound=wound, submitted_by=patient.assigned_doctor, marker_confirmed=True,
                      submission_id=f'LT{uuid.uuid4().hex[:24].upper()}')
        visits.append(visit)
        assessments.append(WoundAssessment(
            wound=wound, visit=visit, ai_versions={'source': 'load_test_bulk'},
            processing_status=WoundAssessment.ProcessingStatus.COMPLETED,
            ai_decision_status='ACCEPTED', calibrated_area_cm2=round(rng.uniform(0.5, 20.0), 2),
            ai_confidence=0.85, risk_tier=rng.choice(['LOW', 'LOW', 'LOW', 'MODERATE', 'HIGH']),
            evaluated_at=now - timedelta(days=rng.uniform(30, 730)),
        ))
        added += 1
    with transaction.atomic():
        Visit.objects.bulk_create(visits)
        WoundAssessment.objects.bulk_create(assessments)
    print(f'  {added}/{missing}')

# Spread the new rows over the past two years (auto_now_add set them to now), older than the seeded series.
with connection.cursor() as cursor:
    cursor.execute("UPDATE visits SET created_at = now() - (interval '1 day' * (30 + random() * 700)) "
                   "WHERE submission_id LIKE 'LT%%' AND created_at > now() - interval '1 day'")
    cursor.execute("UPDATE wound_assessments a SET captured_at = v.created_at, evaluated_at = v.created_at "
                   "FROM visits v WHERE a.visit_id = v.id AND v.submission_id LIKE 'LT%%'")
print(f'visits in total: {Visit.all_objects.count()}, patients in the load-test clinic: {len(patients)}')
