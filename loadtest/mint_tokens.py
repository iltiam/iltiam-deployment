"""Access tokens for the load test (issue #22), printed as one JSON object on stdout.

The local stack runs the production settings with ENVIRONMENT=staging, which only echoes sign-in codes for the
reserved +96659999xxxx numbers; the load-test accounts are +96659998xxxx (doctors) and +96659997xxxx (patients).
So instead of signing in 50 times (and hitting the 5-codes-an-hour limit) each virtual user gets a real session
opened here, exactly what a sign-in opens (apps.accounts.sessions.issue_tokens). Sign-in itself is not what the
NFRs measure. Tokens live 15 minutes: mint them right before the run.

Output: {"doctors": [{"token", "long_wound"}], "upload_patients": [token], "analysis_patients": [token]}
  doctors            the 50 load-test doctors; long_wound = their first patient's wound with 50 visits
  upload_patients    patients 0-49: no AI consent, so an upload is stored without calling the AI service
  analysis_patients  patients 50-99: AI consent, so an upload goes through the queue and the AI service
"""
import json

from django.conf import settings

from apps.accounts.models import User
from apps.accounts.sessions import issue_tokens
from apps.patients.models import Patient
from apps.wounds.models import Wound

assert settings.ENVIRONMENT != 'production', 'never on production'


def doctor_phone(n):
    return f'+96659998{n:04d}'


def patient_phone(n):
    return f'+96659997{n:04d}'


doctors = []
for n in range(1, 51):
    doctor = User.objects.get(phone_number=doctor_phone(n))
    first = Patient.objects.get(user__phone_number=patient_phone(n - 1))
    long_wound = Wound.objects.get(patient_id=first.pk, location=Wound.AnatomicalLocation.DORSAL_FOOT)
    doctors.append({'token': issue_tokens(doctor)['access'], 'long_wound': str(long_wound.pk)})

upload = [issue_tokens(User.objects.get(phone_number=patient_phone(n)))['access'] for n in range(0, 50)]
analysis = [issue_tokens(User.objects.get(phone_number=patient_phone(n)))['access'] for n in range(50, 100)]
print(json.dumps({'doctors': doctors, 'upload_patients': upload, 'analysis_patients': analysis}))
