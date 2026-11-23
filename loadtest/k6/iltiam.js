// ILTIAM load test scenarios (issue #22): run by scripts/loadtest.sh inside the iltiam-dev Compose network.
// SCENARIO picks one: clinicians | upload | analysis. BASE_URL and HOST are set by the script (the local stack only).
//
//   clinicians  50 doctors browse the portal for 3 minutes, against 500 patients and 60,000 image records.
//               NFR-PERF-02 / NFR-SCA-01: each page's API call p95 < 3 s; NFR-PERF-04: the progression of a wound with
//               50 records p95 < 5 s. No 5xx, < 1 % failed requests.
//   upload      5 patients upload a ~10 MB, 8-megapixel photo through a 4G-shaped link (toxiproxy). Upload p95 < 5 s.
//   analysis    patients upload a photo every 5 s for 2 minutes; time from upload to a final result.
//               NFR-PERF-01: < 10 s (target 4 s). With the fake model this measures everything except the model.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';

const SCENARIO = __ENV.SCENARIO || 'clinicians';
const BASE = __ENV.BASE_URL || 'http://backend-web:8000';
const HOST = __ENV.HOST || 'backend-web';
const TOKENS = JSON.parse(open('/work/tokens.json'));
const PHOTO = SCENARIO === 'clinicians' ? null : open('/work/photo-10mb.jpg', 'b');

const analysisE2E = new Trend('analysis_end_to_end', true);
const analysisUnfinished = new Counter('analysis_unfinished');
const serverErrors = new Counter('server_errors');

const scenarios = {
  // VUS and DURATION exist for the small staging run by hand (docs/perf/README.md, section 5): 5 users, 2 minutes.
  clinicians: {
    executor: 'constant-vus', vus: Number(__ENV.VUS || 50), duration: __ENV.DURATION || '3m', exec: 'clinician',
  },
  upload: {
    executor: 'per-vu-iterations', vus: 5, iterations: 6, maxDuration: '5m', exec: 'upload',
  },
  analysis: {
    executor: 'constant-arrival-rate', rate: 1, timeUnit: '5s', duration: '2m',
    preAllocatedVUs: 10, maxVUs: 20, exec: 'analysis',
  },
};

const thresholds = {
  clinicians: {
    'http_req_duration{kind:page}': ['p(95)<3000'],
    'http_req_duration{kind:progression50}': ['p(95)<5000'],
    http_req_failed: ['rate<0.01'],
    server_errors: ['count==0'],
  },
  upload: {
    'http_req_duration{kind:upload}': ['p(95)<5000'],
    server_errors: ['count==0'],
  },
  analysis: {
    analysis_end_to_end: ['p(95)<10000'],
    analysis_unfinished: ['count==0'],
    server_errors: ['count==0'],
  },
};

// One threshold per page as well, so the summary has each page's own p95 (the report's per-page table).
const PAGES = ['/api/patients/', '/api/patients/{id}/', '/api/patients/{id}/wounds/', '/api/wounds/{id}/visits/',
  '/api/wounds/visits/{id}/', '/api/doctor/dashboard/', '/api/wounds/visits/attention/', '/api/alerts/',
  '/api/appointments/', '/api/messages/conversations/'];
if (SCENARIO === 'clinicians') {
  for (const page of PAGES) thresholds.clinicians[`http_req_duration{name:${page}}`] = ['p(95)<3000'];
}

export const options = {
  scenarios: { [SCENARIO]: scenarios[SCENARIO] },
  thresholds: thresholds[SCENARIO],
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'max', 'count'],
  // One test machine for every virtual user; the backend's per-user limits still apply.
  noConnectionReuse: false,
};

function params(token, name, kind, extra = {}) {
  return { headers: { Host: HOST, Authorization: `Bearer ${token}`, ...extra }, tags: { name, kind } };
}

function get(token, path, name, kind = 'page') {
  const res = http.get(`${BASE}${path}`, params(token, name, kind));
  if (res.status >= 500) serverErrors.add(1);
  check(res, { [`${name} 200`]: (r) => r.status === 200 });
  return res;
}

// --- clinicians ---------------------------------------------------------------------------------------------------
export function clinician() {
  const doctor = TOKENS.doctors[(__VU - 1) % TOKENS.doctors.length];
  const t = doctor.token;
  const list = get(t, '/api/patients/', '/api/patients/');
  const patients = list.status === 200 ? list.json('results') || [] : [];
  sleep(1 + Math.random() * 2);
  if (patients.length) {
    const p = patients[Math.floor(Math.random() * patients.length)];
    get(t, `/api/patients/${p.id}/`, '/api/patients/{id}/');
    sleep(1 + Math.random() * 2);
    const wounds = get(t, `/api/patients/${p.id}/wounds/`, '/api/patients/{id}/wounds/');
    const w = wounds.status === 200 ? (wounds.json('results') || wounds.json() || [])[0] : null;
    if (w && w.id) {
      const visits = get(t, `/api/wounds/${w.id}/visits/`, '/api/wounds/{id}/visits/');
      const v = visits.status === 200 ? (visits.json('results') || [])[0] : null;
      if (v && (v.id || v.visit_id)) get(t, `/api/wounds/visits/${v.id || v.visit_id}/`, '/api/wounds/visits/{id}/');
    }
    sleep(1 + Math.random() * 2);
  }
  get(t, '/api/doctor/dashboard/', '/api/doctor/dashboard/');
  get(t, '/api/wounds/visits/attention/', '/api/wounds/visits/attention/');
  get(t, '/api/alerts/', '/api/alerts/');
  sleep(1 + Math.random() * 2);
  get(t, '/api/appointments/?status=PENDING', '/api/appointments/');
  get(t, '/api/messages/conversations/', '/api/messages/conversations/');
  get(t, `/api/wounds/${doctor.long_wound}/progression/`, '/api/wounds/{id}/progression/ (50 visits)', 'progression50');
  sleep(1 + Math.random() * 2);
}

// --- uploads --------------------------------------------------------------------------------------------------------
function postPhoto(token, kind) {
  const body = {
    image: http.file(PHOTO, 'wound.jpg', 'image/jpeg'),
    anatomical_location: 'HEEL',
    marker_confirmed: 'true',
    confirm_duplicate: 'true',
  };
  const key = `lt-${__VU}-${__ITER}-${Date.now()}`;
  const res = http.post(`${BASE}/api/wounds/mine/upload/`, body,
    params(token, '/api/wounds/mine/upload/', kind, { 'Idempotency-Key': key }));
  if (res.status >= 500) serverErrors.add(1);
  check(res, { 'upload 201': (r) => r.status === 201 });
  return res;
}

export function upload() {
  postPhoto(TOKENS.upload_patients[(__VU - 1) % TOKENS.upload_patients.length], 'upload');
  sleep(2 + Math.random() * 3);
}

// --- analysis end to end ----------------------------------------------------------------------------------------------
export function analysis() {
  // One analysis in progress per patient (backend queueing): each iteration takes the next patient.
  const n = (__VU * 7 + __ITER) % TOKENS.analysis_patients.length;
  const token = TOKENS.analysis_patients[n];
  const start = Date.now();
  const res = postPhoto(token, 'analysis_upload');
  if (res.status !== 201) { analysisUnfinished.add(1); return; }
  const visit = res.json('visit.id') || res.json('id');
  for (let i = 0; i < 180; i++) {  // up to about 45 s, past the backend's 30 s AI timeout
    const r = http.get(`${BASE}/api/wounds/mine/visits/${visit}/`,
      params(token, '/api/wounds/mine/visits/{id}/', 'poll'));
    if (r.status >= 500) serverErrors.add(1);
    if (r.status === 200 && r.json('state') !== 'PROCESSING') {
      analysisE2E.add(Date.now() - start);
      return;
    }
    sleep(0.25);
  }
  analysisUnfinished.add(1);
}

export function handleSummary(data) {
  return { [`/work/${SCENARIO}-summary.json`]: JSON.stringify(data, null, 2) };
}
