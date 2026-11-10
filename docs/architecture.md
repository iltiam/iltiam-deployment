# System architecture (C4)

ILTIAM as built: what talks to what, and where it runs. Written from the code and the Compose stack, not from the
SRS diagrams (the differences are in [SRS divergences](srs-divergences.md)). The flows between the parts are in the
[integration guide](integration.md).

## Level 1: system context

```mermaid
flowchart LR
    patient["Patient<br/>(Android app)"]
    doctor["Doctor<br/>(web portal, Android app)"]
    cadmin["Clinic Admin<br/>(web portal)"]
    sadmin["Super Admin<br/>(web portal)"]
    iltiam(["ILTIAM<br/>wound monitoring and clinical decision support"])
    authentica["Authentica<br/>SMS and WhatsApp codes, SMS notices"]
    fcm["Firebase Cloud Messaging<br/>push to the Android app"]
    email["OCI Email Delivery<br/>email codes and notices"]
    cloudflare["Cloudflare<br/>DNS, TLS, WAF, Tunnel"]

    patient -->|photos, results, messages, appointments| iltiam
    doctor -->|patients, reviews, notes, prescriptions| iltiam
    cadmin -->|doctors, reassignment, statistics| iltiam
    sadmin -->|clinics, admins, AI model, audit| iltiam
    iltiam --> authentica
    iltiam --> fcm
    iltiam --> email
    cloudflare -.->|every request comes in through| iltiam
```

- **Patients** use the Android app only (iOS is v1.1, [SD-11](srs-divergences.md)).
- **Doctors** use the web portal and the same app ([SD-04](srs-divergences.md)).
- **Admins** use the web portal only; the backend refuses them in the app (`WEB_PORTAL_ONLY`, iltiam-backend#106).

## Level 2: containers

One Oracle Cloud ARM VM in Riyadh runs staging and production as two Compose projects
([ADR-0004](adr/0004-hosting.md), [Runbook 5](runbooks/05-compose-stack.md), [`compose.yml`](https://github.com/iltiam/iltiam-deployment/blob/main/compose.yml)).
Each project has the containers below.

```mermaid
flowchart TB
    subgraph edge["Cloudflare"]
        tunnel["Tunnel<br/>app. / api. hostnames"]
    end
    subgraph vm["OCI VM, one Compose project per environment"]
        cloudflared["cloudflared"]
        web["web<br/>nginx + React SPA<br/>(iltiam-web)"]
        api["backend-web<br/>Django REST API<br/>(iltiam-backend)"]
        worker["backend-worker / backend-beat<br/>Celery: AI jobs, notices, reminders"]
        ai["ai-api<br/>AI service API<br/>(iltiam-ai-service)"]
        aiw["ai-worker / ai-beat<br/>ALG-01..05 pipeline"]
        pg[("postgres<br/>iltiam, iltiam_ai")]
        redis[("redis<br/>cache, Celery broker")]
    end
    storage[("OCI Object Storage<br/>photos, masks, prescriptions")]
    app["Android app<br/>(iltiam-mobile)"]
    browser["Browser"]

    browser --> tunnel
    app --> tunnel
    tunnel --> cloudflared
    cloudflared -->|app.| web
    cloudflared -->|api.| api
    web -.->|the SPA calls| api
    api --> pg
    api --> redis
    worker --> redis
    worker --> pg
    worker -->|POST /v1/analyze, GET /v1/jobs/id, POST /v1/progression| ai
    ai --> aiw
    aiw --> redis
    aiw --> pg
    api -->|presigned links| storage
    worker --> storage
```

- **Only `web` and `backend-web` are reachable from the internet**, through the tunnel; the AI service is never
  routed ([Runbook 3](runbooks/03-cloudflare-tunnels.md)). No container publishes a port.
- **Files** live in OCI Object Storage (private, encrypted buckets); clients get presigned links of at most
  15 minutes.
- **The AI service** has its own database (`iltiam_ai`) and queue; the backend reaches it with a service token.

## Level 3: the backend's modules

The backend is a modular monolith ([iltiam-backend](https://github.com/iltiam/iltiam-backend)):

| App | Holds |
|---|---|
| `accounts` | users, two-step sign-in, sessions, step-up, Super Admin invitations |
| `clinics` | clinics, doctors, reassignment, clinic event log |
| `patients` | patients, consents, data export and deletion, doctor dashboard |
| `wounds` | wounds, visits, uploads, the AI job and progression |
| `analysis` | doctor reviews, alerts, the corrections dataset |
| `clinical` | SOAP notes, prescriptions, care plans |
| `appointments`, `messaging` | appointments and next-visit reminders; patient–doctor messages |
| `notifications` | the notification catalogue, push, SMS, email, reminders, breach notices |
| `reports` | statistics and PDF reports |
| `storage`, `integrations.ai` | object storage; the AI service client and its vendored contract |
| `core` | audit log, errors, rate limits, retention |
