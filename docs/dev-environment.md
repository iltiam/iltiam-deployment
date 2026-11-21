# Local development environment

The whole ILTIAM system on your own machine with one command (issue #5): the backend (web, worker, beat), the AI
service (api, worker, beat), the web app, PostgreSQL, Redis, MinIO for files and mailpit for email. It runs the
**same images as staging** (`env/staging.versions`), with the same settings code, so what works here works there.
Nothing in it talks to staging, production, Oracle, Cloudflare, Authentica or Firebase.

Files: [`compose.dev.yml`](https://github.com/iltiam/iltiam-deployment/blob/main/compose.dev.yml) and
[`scripts/dev.sh`](https://github.com/iltiam/iltiam-deployment/blob/main/scripts/dev.sh) (PowerShell:
`scripts/dev-up.ps1`, `scripts/dev-reset.ps1`).

## 1. Quick start (about 20 minutes on a clean machine)

1. Install **Docker Desktop** (give it at least 6 GB of memory: Settings, Resources) and **Git for Windows** (it brings
   Git Bash, `curl` and `openssl`). Install `jq` (`winget install jqlang.jq`).
2. Clone the repositories side by side, for example in `C:\ai\gradutionProject\ILTIAM\`:
   `iltiam-deployment`, `iltiam-backend`, `iltiam-web`, `iltiam-ai-service` (and `iltiam-mobile` for the app).
3. Sign Docker in to GHCR once: the ILTIAM images are private. You need a GitHub account in the `iltiam` organisation.

    ```bash
    gh auth refresh -s read:packages
    gh auth token | docker login ghcr.io -u <your GitHub user name> --password-stdin
    ```

    No access to the packages? Build the images from your clones instead (step 4 with `--build all`, about 10
    more minutes the first time).

4. Start everything, from `iltiam-deployment`:

    ```bash
    scripts/dev.sh up                    # Git Bash
    .\scripts\dev-up.ps1                 # PowerShell, same thing
    scripts/dev.sh up --build backend    # use your iltiam-backend clone instead of staging's backend image
    ```

    The first `up` makes `.dev/dev.env` (random development-only keys, gitignored), pulls the images, waits until
    every container is healthy (about 1 minute once the images are there) and seeds the demo data. At the end it
    prints the demo accounts and the addresses below.

5. Open <http://localhost:8080> and sign in as the demo doctor: phone `+966599990001`, password `Iltiam@2026`. The
   page shows the 6-digit test code (the backend runs with `ENVIRONMENT=staging`, which echoes codes for the reserved
   test numbers only).
6. Check the whole chain: `scripts/dev.sh smoke` (section 6).

| Address | What |
|---|---|
| <http://localhost:8080> | Web app (doctors, clinic admins, Super Admins) |
| <http://localhost:8000/api/> | Backend API; Swagger at <http://localhost:8000/api/docs/> |
| <http://localhost:8025> | mailpit: every email the backend sends (activation links, notices) |
| <http://localhost:9001> | MinIO console (user `iltiam-minio-admin`, password `DEV_MINIO_ROOT_PASSWORD` in `.dev/dev.env`) |
| <http://localhost:8001> | AI service API, for debugging (needs the token `DEV_AI_SERVICE_TOKEN`) |

Every port is published on `127.0.0.1` only (section 5 for a phone). They differ from the ports of the backend's and
AI service's own compose files except 8000, so stop those first (`docker compose down` in those clones).

## 2. Commands

| Command | What it does | Time |
|---|---|---|
| `scripts/dev.sh up [--build backend,web,ai\|all\|staging] [--real-model] [--no-seed]` | Start or update the stack; seed the demo once | ~1 min |
| `scripts/dev.sh reset` (`.\scripts\dev-reset.ps1`) | Wipe the backend's database, queues and files, start again, seed the demo dated to today | ~40 s |
| `scripts/dev.sh reset --all` | Remove every volume (the AI service's too) and start from scratch | ~70 s |
| `scripts/dev.sh seed` | Rebuild the demo data dated to today (`seed_demo --reset`), keep everything else | ~10 s |
| `scripts/dev.sh smoke` | API smoke (section 6) | ~15 s |
| `scripts/dev.sh codes` | The last sign-in codes the console SMS backend logged | |
| `scripts/dev.sh status`, `logs [service]`, `down [--volumes]` | Container states, logs, stop | |
| `scripts/dev.sh compose <args>` | Any `docker compose` command on this project (`compose exec backend-web python manage.py shell`) | |

`--build` remembers its choice: a later `up` without `--build` keeps the same images; `--build staging` goes back to
staging's tags.

## 3. Accounts and data

`seed_demo` (iltiam-backend, `docs/demo.md` there) creates one clinic with a doctor, a clinic admin, two Super Admins
(one read-only) and 8 patients with 4 to 6 weekly visits each: improving, stalled and deteriorating cases with alerts.
All use the password `Iltiam@2026`.

| Role | Phone |
|---|---|
| Doctor | `+966599990001` |
| Super Admin (full) | `+966599990002` |
| Clinic Admin | `+966599990003` |
| Super Admin (read-only) | `+966599990004` |
| Patients | `+966599990101` to `+966599990108` |

All numbers are in the reserved test range `+96659999xxxx`, so their codes come back in the login response
(`dev_otp_code`) and the web page shows them. Any other code (a number you created yourself) is only in the backend
log: `scripts/dev.sh codes`. Emails (activation, password reset, breach notices) are in mailpit.

The staging test accounts (`+966599999000` and the others) work too, after
`scripts/dev.sh compose exec backend-web python manage.py seed_staging --password '<a password you choose>'`.

A real analysis series through the AI service (iltiam-backend#70, `seed_ai_series`) needs photos with the 50 mm
marker and the real model (section 4):
`scripts/dev.sh compose exec backend-web python manage.py seed_ai_series --patient +966599990101 --location HEEL --images ... --days-ago ...`
(copy the photos into the container first with `scripts/dev.sh compose cp`).

## 4. The AI model

By default the AI service runs the **weight-free fake model** (`ILTIAM_SEG_MODEL=fake`): no download, answers in
milliseconds, and a photo without a marker comes back as "retake". That is enough for every screen and flow.

For real measurements, start with the real model. It downloads the weights from the iltiam-ai-service
releases with **your own** GitHub token, read from your shell only, never written to a file:

```bash
export WEIGHTS_READ_TOKEN=$(gh auth token)   # needs read access to iltiam/iltiam-ai-service
scripts/dev.sh up --real-model
```

The weights stay in the `weights` volume until `reset --all`. Each AI process then loads the real pipeline (about 1.2 GB), so give Docker 8 GB.

## 5. Mobile app (Android)

The dev flavor talks to the real backend with `MOCK_BACKEND=false` and an `API_BASE_URL` (scheme, host and port only,
no `/api`). From the `iltiam-mobile` clone:

**Android emulator** (`10.0.2.2` is the emulator's name for your computer):

```bash
flutter run --flavor dev --dart-define-from-file=config/flavors/dev.json \
  --dart-define=MOCK_BACKEND=false --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Photos and thumbnails are links signed for `http://localhost:9000`. In the emulator, forward that port so they load:
`adb reverse tcp:9000 tcp:9000`.

**A phone on USB** (simplest, no network changes): forward both ports and use `localhost`:

```bash
adb reverse tcp:8000 tcp:8000
adb reverse tcp:9000 tcp:9000
flutter run --flavor dev --dart-define-from-file=config/flavors/dev.json \
  --dart-define=MOCK_BACKEND=false --dart-define=API_BASE_URL=http://localhost:8000
```

**A phone on the same Wi-Fi**: publish the API and MinIO on your LAN address and sign file links for it. Only on a
network you trust (home), never on a public Wi-Fi: the demo accounts have a published password.

```bash
DEV_BIND=0.0.0.0 DEV_PUBLIC_HOST=192.168.1.20 scripts/dev.sh up      # your computer's address (ipconfig)
flutter run ... --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

Windows may ask to allow Docker through the firewall: allow it for private networks only. With `DEV_PUBLIC_HOST` set,
the photos in the web app at `localhost:8080` no longer load (their links point at the LAN address); run
`scripts/dev.sh up` again without it when you are done. Patients sign in with the code from the login response only in
staging builds; in the dev flavor read it with `scripts/dev.sh codes`.

## 6. Web app from source and the API smoke

**Web from source** (hot reload): leave the stack running and start Vite in `iltiam-web/web`. Its proxy sends `/api`
to the stack's backend, and the backend already allows `http://localhost:5173`:

```bash
cp .env.example .env.local      # VITE_DATA_SOURCE=api, VITE_PROXY_TARGET=http://localhost:8000
npm run dev
```

**Backend or AI from source**: build your branch into the stack with `scripts/dev.sh up --build backend` (or `ai`);
for a debugger, stop that container (`scripts/dev.sh compose stop backend-web`) and run the clone's own instructions
against `localhost`.

**API smoke** (`scripts/dev.sh smoke`), also an optional check in `scripts/ci-local.sh --full` whenever the stack is
running:

1. Backend `/api/health/` 200 and `/api/ready/` ready (database, Redis, storage and AI service all answer).
2. AI service `/ready`, web `/healthz`, web `/config.js` points at the local API, mailpit, MinIO.
3. The demo doctor signs in (password, then the echoed code) and opens the dashboard.
4. A demo patient signs in, uploads a photo, and the analysis goes through the queue, the AI service and back to a
   final status (with the fake model: `RETAKE_REQUIRED`, the photo has no marker).

Recorded on 2026-11-21 (Windows 11, Docker Desktop 29.8.0, Compose 5.5.1, fake model): `up` 70 s with a backend
build from cache, all 12 smoke checks PASS, `reset` 41 s.

## 7. How it differs from staging

| | Staging (`compose.yml`) | Local (`compose.dev.yml`) |
|---|---|---|
| Images | `env/staging.versions` | The same, or built from your clones (`--build`) |
| Backend settings | production settings, `ENVIRONMENT=staging` | The same |
| Files | OCI Object Storage | MinIO (five private, encrypted, versioned buckets) |
| SMS / push | Authentica / console push | Console backends (codes in the log) |
| Email | SMTP | mailpit |
| AI model | real weights | fake by default, real with `--real-model` |
| Network | Cloudflare Tunnel, no ports | `127.0.0.1` ports, HTTP |
| Secrets | GitHub Environment, `/srv/iltiam/env` | Random dev-only keys in `.dev/dev.env` |

Because it is HTTP, the backend's secure cookies are not sent: the Django admin (`/admin/`) does not sign in here.
Everything the apps use (JWT) works.

## 8. Troubleshooting

| What you see | Fix |
|---|---|
| `can't pull ghcr.io/iltiam/...` | Sign Docker in to GHCR (section 1, step 3) or `--build` that image |
| `port is already allocated` | Another stack uses the port: `docker ps`, then stop it (usually the backend or AI repo's own compose) |
| A container stays unhealthy | `scripts/dev.sh logs <service>`; `scripts/dev.sh reset --all` if the volumes are from an older version |
| Sign-in says the code is wrong or expired | Use the newest code (`scripts/dev.sh codes`); five wrong tries lock the account 10 minutes, `reset` clears it |
| Photos do not load in the app | Port 9000 is not reachable from the device: `adb reverse tcp:9000 tcp:9000` (section 5) |
| You want new keys | Delete `.dev/dev.env`, then `scripts/dev.sh reset --all` |
