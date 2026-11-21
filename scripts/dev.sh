#!/usr/bin/env bash
# The whole ILTIAM system on this machine (issue #5): compose.dev.yml, docs/dev-environment.md.
#
#   scripts/dev.sh up [--build <list>] [--real-model] [--no-seed]
#                          start everything, wait until healthy, seed the demo data (first time only)
#   scripts/dev.sh reset [--all]
#                          wipe the backend's database, queues and files, start again, seed the demo data;
#                          --all removes every volume (the AI service's too) and starts from scratch
#   scripts/dev.sh seed    rebuild the demo data dated to today (manage.py seed_demo --reset)
#   scripts/dev.sh smoke   API smoke: health, readiness, web config, a real sign-in with the demo doctor
#   scripts/dev.sh codes   the latest SMS sign-in codes the console backend logged
#   scripts/dev.sh status | logs [service...] | down [--volumes] | compose <docker compose arguments...>
#
#   --build <list>   build images from the sibling clones instead of using staging's tags: backend, web, ai or all,
#                    comma-separated (e.g. --build backend), or staging to go back to staging's tags. Without --build,
#                    `up` reuses the images of the last `up`. Clones are found in DEV_SRC_ROOT (default: ..).
#   --real-model     the real segmentation model: downloads the weights with WEIGHTS_READ_TOKEN from your shell
#                    (a GitHub token with read access to iltiam-ai-service releases). Default: the weight-free fake.
#   --no-seed        do not seed the demo data.
#
# Environment: DEV_BIND=0.0.0.0 publishes the API and MinIO on the LAN (a phone on Wi-Fi); DEV_PUBLIC_HOST=<LAN IP>
# signs file links for that address. Both are explained in docs/dev-environment.md, section 5.
#
# Local only: this script never talks to staging, production or any cloud account. The keys it generates in
# .dev/dev.env are random development-only values; .dev/ is gitignored.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=iltiam-dev
DEV_DIR=.dev
KEYS="$DEV_DIR/dev.env"
IMAGES="$DEV_DIR/images.env"
SRC_ROOT="${DEV_SRC_ROOT:-..}"
WAIT_S="${DEV_WAIT_S:-600}"
API="http://127.0.0.1:8000"
# The demo doctor (iltiam-backend apps/wounds/demo/scenarios.py). Its password is printed by seed_demo too.
DEMO_DOCTOR="+966599990001"
DEMO_PASSWORD="Iltiam@2026"

die() { printf 'dev.sh: %s\n' "$*" >&2; exit 1; }
say() { printf '\n== %s\n' "$*"; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed ($2)"; }

compose() {
  [ -f "$KEYS" ] || die "no $KEYS yet: run scripts/dev.sh up first"
  [ -f "$IMAGES" ] || die "no $IMAGES yet: run scripts/dev.sh up first"
  # MSYS_NO_PATHCONV: Git Bash would turn container paths such as /bin/sh into Windows paths.
  MSYS_NO_PATHCONV=1 docker compose -p "$PROJECT" -f compose.dev.yml --env-file "$IMAGES" --env-file "$KEYS" "$@"
}

# --- Keys: random, development only, made once ------------------------------------------------------------------
rand_hex() { openssl rand -hex "$1"; }
fernet_key() { openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n'; }

echo_numbers() {
  # The reserved test range only (+96659999xxxx): demo seed 0001-0004 and 0101-0108, staging seed 9000-9026.
  local n out=""
  for n in 0001 0002 0003 0004 0101 0102 0103 0104 0105 0106 0107 0108 \
           9000 9001 9011 9012 9021 9022 9023 9024 9025 9026; do
    out="$out${out:+,}+96659999$n"
  done
  printf '%s' "$out"
}

ensure_keys() {
  mkdir -p "$DEV_DIR"
  [ -f "$KEYS" ] && return 0
  umask 077
  {
    echo "# Made by scripts/dev.sh on $(date -u +%Y-%m-%d). Development only, random, never used anywhere else."
    echo "# Delete this file and run 'scripts/dev.sh reset' to make new ones."
    echo "DEV_SECRET_KEY=$(rand_hex 32)"
    echo "DEV_JWT_SECRET_KEY=$(rand_hex 32)"
    echo "DEV_FIELD_ENCRYPTION_KEY=$(fernet_key)"
    echo "DEV_AI_SERVICE_TOKEN=$(rand_hex 24)"
    echo "DEV_AI_DJANGO_SECRET_KEY=$(rand_hex 32)"
    echo "DEV_POSTGRES_PASSWORD=$(rand_hex 16)"
    echo "DEV_BACKEND_DB_PASSWORD=$(rand_hex 16)"
    echo "DEV_AI_DB_PASSWORD=$(rand_hex 16)"
    echo "DEV_MINIO_ROOT_PASSWORD=$(rand_hex 16)"
    echo "DEV_MINIO_KMS_KEY=$(openssl rand -base64 32 | tr -d '\n')"
    echo "DEV_STORAGE_SECRET_KEY=$(rand_hex 16)"
    echo "DEV_OTP_ECHO_NUMBERS=$(echo_numbers)"
  } >"$KEYS"
  echo "Made $KEYS (random development-only keys)."
}

# --- Images: staging's tags, or built from the sibling clones ---------------------------------------------------
staging_image() {
  sed -n "s/^$1=//p" env/staging.versions | tr -d '\r' | tail -n 1
}

have_image() { docker image inspect "$1" >/dev/null 2>&1; }

pull_or_explain() {
  local image="$1" what="$2"
  have_image "$image" && return 0
  echo "Pulling $image"
  docker pull -q "$image" >/dev/null 2>&1 && return 0
  die "can't pull $image. The ILTIAM images on GHCR are private: sign in once with
  gh auth refresh -s read:packages && gh auth token | docker login ghcr.io -u <your GitHub user> --password-stdin
or build it from your clone instead: scripts/dev.sh up --build $what"
}

build_image() {
  local what="$1" src
  case "$what" in
    backend)
      src="$SRC_ROOT/iltiam-backend"; [ -f "$src/Dockerfile" ] || die "no $src/Dockerfile (set DEV_SRC_ROOT)"
      say "Building iltiam-backend:dev from $src"
      docker build -q -t iltiam-backend:dev "$src" >/dev/null ;;
    web)
      src="$SRC_ROOT/iltiam-web/web"; [ -f "$src/Dockerfile" ] || die "no $src/Dockerfile (set DEV_SRC_ROOT)"
      say "Building iltiam-web:dev from $src"
      docker build -q -t iltiam-web:dev "$src" >/dev/null ;;
    ai)
      src="$SRC_ROOT/iltiam-ai-service"; [ -f "$src/Dockerfile" ] || die "no $src/Dockerfile (set DEV_SRC_ROOT)"
      say "Building iltiam-ai-api:dev and iltiam-ai-worker:dev from $src"
      docker build -q --target api -t iltiam-ai-api:dev "$src" >/dev/null
      docker build -q --target worker -t iltiam-ai-worker:dev "$src" >/dev/null ;;
    *) die "--build takes backend, web, ai or all (got $what)" ;;
  esac
}

resolve_images() {
  local build_list="$1" backend web ai_api ai_worker
  backend="$(staging_image BACKEND_IMAGE)"
  web="$(staging_image WEB_IMAGE)"
  ai_api="$(staging_image AI_API_IMAGE)"
  ai_worker="$(staging_image AI_WORKER_IMAGE)"
  [ "$build_list" = all ] && build_list="backend,web,ai"
  local item
  for item in ${build_list//,/ }; do
    build_image "$item"
    case "$item" in
      backend) backend=iltiam-backend:dev ;;
      web) web=iltiam-web:dev ;;
      ai) ai_api=iltiam-ai-api:dev; ai_worker=iltiam-ai-worker:dev ;;
    esac
  done
  pull_or_explain "$backend" backend
  pull_or_explain "$web" web
  pull_or_explain "$ai_api" ai
  pull_or_explain "$ai_worker" ai
  mkdir -p "$DEV_DIR"
  {
    echo "# Written by scripts/dev.sh up: the images this local stack runs."
    echo "BACKEND_IMAGE=$backend"
    echo "WEB_IMAGE=$web"
    echo "AI_API_IMAGE=$ai_api"
    echo "AI_WORKER_IMAGE=$ai_worker"
  } >"$IMAGES"
  echo "Images: backend $backend, web $web, ai $ai_api"
}

# --- Commands ------------------------------------------------------------------------------------------------------
start_stack() {
  local real_model="$1"
  if [ "$real_model" = 1 ]; then
    [ -n "${WEIGHTS_READ_TOKEN:-}" ] || die "--real-model needs WEIGHTS_READ_TOKEN in your shell (docs/dev-environment.md, section 4)"
    export COMPOSE_PROFILES=real-model DEV_SEG_MODEL=segformer-b2
  else
    export COMPOSE_PROFILES="" DEV_SEG_MODEL=fake
  fi
  say "Starting $PROJECT (model: $DEV_SEG_MODEL)"
  compose up -d --remove-orphans --wait --wait-timeout "$WAIT_S"
}

seed() {
  say "Demo data (manage.py seed_demo $*)"
  compose exec -T backend-web python manage.py seed_demo "$@"
}

print_urls() {
  cat <<EOF

ILTIAM is running on this machine:
  Web app        http://localhost:8080        (sign in with a demo account above; the code shows on the page)
  API            http://localhost:8000/api/   (docs: http://localhost:8000/api/docs/)
  Emails         http://localhost:8025        (mailpit)
  Files          http://localhost:9001        (MinIO console; user iltiam-minio-admin, password in $KEYS)
  Android        flutter run --flavor dev --dart-define-from-file=config/flavors/dev.json \\
                   --dart-define=MOCK_BACKEND=false --dart-define=API_BASE_URL=http://10.0.2.2:8000
Reset everything: scripts/dev.sh reset    Stop: scripts/dev.sh down
EOF
}

cmd_up() {
  local build_list="" real_model=0 do_seed=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --build) [ $# -ge 2 ] || die "--build needs a list"; build_list="$2"; shift 2 ;;
      --real-model) real_model=1; shift ;;
      --no-seed) do_seed=0; shift ;;
      *) die "unknown option for up: $1" ;;
    esac
  done
  need docker "Docker Desktop"; need openssl "comes with Git for Windows"
  docker info >/dev/null 2>&1 || die "the Docker daemon is not running: start Docker Desktop"
  ensure_keys
  # Without --build, a later `up` keeps the images the last one chose (`--build staging` goes back to staging's).
  if [ -z "$build_list" ] && [ -f "$IMAGES" ]; then
    echo "Images: as last time ($IMAGES)"
  else
    [ "$build_list" = staging ] && build_list=""
    resolve_images "$build_list"
  fi
  start_stack "$real_model"
  # Seed once: a database that already has the demo is left alone (seed_demo without --reset).
  [ "$do_seed" = 1 ] && seed
  print_urls
}

cmd_reset() {
  local start=$SECONDS
  [ -f "$IMAGES" ] || die "nothing to reset: run scripts/dev.sh up first"
  if [ "${1:-}" = --all ]; then
    say "Removing $PROJECT and every volume (local databases, files, queues and downloaded weights)"
    compose down -v --remove-orphans --timeout 5
  else
    # The backend's data only; the AI service keeps running (its jobs expire on their own).
    say "Wiping the backend's database, queues and files"
    compose stop --timeout 5 web backend-web backend-worker backend-beat
    compose exec -T postgres psql -q -v ON_ERROR_STOP=1 -U postgres -d postgres \
      -c "DROP DATABASE IF EXISTS iltiam WITH (FORCE);" \
      -c "CREATE DATABASE iltiam OWNER iltiam;" \
      -c "REVOKE ALL ON DATABASE iltiam FROM PUBLIC;"
    compose exec -T redis sh -c 'redis-cli -n 0 FLUSHDB >/dev/null && redis-cli -n 2 FLUSHDB >/dev/null'
    # The $ names below are expanded by the container's shell, not this one.
    # shellcheck disable=SC2016
    compose run --rm --no-deps --entrypoint /bin/sh minio-init -c '
      mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null &&
      for b in wound-images wound-masks reports prescriptions profile-photos; do
        mc rm --recursive --force --versions "local/$b" >/dev/null 2>&1 || true
      done && echo "Buckets emptied."'
  fi
  start_stack 0
  seed --reset
  print_urls
  echo "Reset took $((SECONDS - start)) s."
}

http_code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

# A demo patient (Improving, heel wound) for the end-to-end upload.
DEMO_PATIENT="+966599990101"
# A 640x480 JPEG made inside the backend container (Pillow is there), so the smoke needs no Python here.
MAKE_PHOTO='import io, sys
from PIL import Image, ImageDraw
img = Image.new("RGB", (640, 480), (214, 180, 160))
d = ImageDraw.Draw(img)
d.ellipse((250, 170, 390, 300), fill=(150, 40, 40))
d.rectangle((60, 60, 160, 160), fill=(0, 0, 0))
buf = io.BytesIO()
img.save(buf, "JPEG", quality=90)
sys.stdout.buffer.write(buf.getvalue())'

# sign_in <phone> <web|mobile>: prints an access token, or nothing. Works only for the reserved test numbers,
# whose code the login response echoes (OTP_DEV_ECHO_NUMBERS).
sign_in() {
  local body challenge otp
  body="$(curl -s -H 'Content-Type: application/json' \
    -d "{\"phone_number\":\"$1\",\"password\":\"$DEMO_PASSWORD\",\"client\":\"$2\"}" "$API/api/auth/login/" || true)"
  challenge="$(jq -r '.challenge_id // empty' <<<"$body" 2>/dev/null || true)"
  otp="$(jq -r '.dev_otp_code // empty' <<<"$body" 2>/dev/null || true)"
  if [ -z "$challenge" ] || [ -z "$otp" ]; then
    jq -r '.tokens.access // empty' <<<"$body" 2>/dev/null || true
    return 0
  fi
  body="$(curl -s -H 'Content-Type: application/json' \
    -d "{\"challenge_id\":\"$challenge\",\"otp_code\":\"$otp\"}" "$API/api/auth/login/verify/" || true)"
  jq -r '.tokens.access // empty' <<<"$body" 2>/dev/null || true
}

cmd_smoke() {
  need curl "curl"; need jq "jq"
  local fails=0 code body access
  check() {  # check <name> <condition result 0/1>
    if [ "$2" = 0 ]; then printf '  PASS  %s\n' "$1"; else printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); fi
  }
  say "API smoke against the local stack"
  code="$(http_code "$API/api/health/")"; check "backend /api/health/ 200 (got $code)" "$([ "$code" = 200 ]; echo $?)"
  body="$(curl -s "$API/api/ready/" || true)"
  check "backend /api/ready/ ready (database, redis, storage, AI)" "$(jq -e '.status == "ready"' >/dev/null 2>&1 <<<"$body"; echo $?)"
  code="$(http_code http://127.0.0.1:8001/ready)"; check "AI /ready 200 (got $code)" "$([ "$code" = 200 ]; echo $?)"
  code="$(http_code http://127.0.0.1:8080/healthz)"; check "web /healthz 200 (got $code)" "$([ "$code" = 200 ]; echo $?)"
  body="$(curl -s http://127.0.0.1:8080/config.js || true)"
  check "web /config.js points at http://localhost:8000" "$(grep -q 'http://localhost:8000' <<<"$body"; echo $?)"
  code="$(http_code http://127.0.0.1:8025/)"; check "mailpit 200 (got $code)" "$([ "$code" = 200 ]; echo $?)"
  code="$(http_code http://127.0.0.1:9000/minio/health/live)"; check "MinIO live 200 (got $code)" "$([ "$code" = 200 ]; echo $?)"

  local doctor
  doctor="$(sign_in "$DEMO_DOCTOR" web)"
  check "demo doctor signs in (password, then the echoed test code)" "$([ -n "$doctor" ]; echo $?)"
  code="000"
  [ -n "$doctor" ] && code="$(http_code -H "Authorization: Bearer $doctor" "$API/api/doctor/dashboard/")"
  check "doctor dashboard with that token 200 (got $code)" "$([ "$code" = 200 ]; echo $?)"

  # End to end: a demo patient uploads a photo, the backend queues it, the AI service (fake model) analyses it and
  # the backend stores the result. Any final status counts: the fake model's answer is not the point here.
  local photo visit status="none" i=0
  access="$(sign_in "$DEMO_PATIENT" mobile)"
  check "demo patient signs in" "$([ -n "$access" ]; echo $?)"
  if [ -n "$access" ]; then
    photo="$DEV_DIR/smoke-photo.jpg"
    compose exec -T backend-web python -c "$MAKE_PHOTO" >"$photo"
    body="$(curl -s -H "Authorization: Bearer $access" -H "Idempotency-Key: smoke-$(rand_hex 8)" \
      -F "image=@$photo;type=image/jpeg" -F anatomical_location=HEEL -F marker_confirmed=true \
      -F confirm_duplicate=true "$API/api/wounds/mine/upload/" || true)"
    visit="$(jq -r '.visit.id // .id // empty' <<<"$body" 2>/dev/null || true)"
    check "patient uploads a photo (visit created)" "$([ -n "$visit" ]; echo $?)"
    [ -n "$visit" ] || printf '        response: %s\n' "$(jq -c '{code, detail, error}' <<<"$body" 2>/dev/null | head -c 300)"
    if [ -n "$visit" ]; then
      for i in $(seq 1 60); do
        # The doctor's view has the analysis status; the patient's only says "processing" or the outcome.
        status="$(curl -s -H "Authorization: Bearer $doctor" "$API/api/wounds/visits/$visit/" \
          | jq -r '.status // empty' 2>/dev/null || true)"
        case "$status" in COMPLETED | MANUAL_REVIEW | RETAKE_REQUIRED | FAILED) break ;; esac
        sleep 1
      done
    fi
    check "analysis finished through the AI service (status $status, after $i s)" \
      "$(case "$status" in COMPLETED | MANUAL_REVIEW | RETAKE_REQUIRED) echo 0 ;; *) echo 1 ;; esac)"
  fi

  if [ "$fails" -eq 0 ]; then echo "Smoke: all checks passed."; else echo "Smoke: $fails check(s) failed."; return 1; fi
}

cmd_codes() {
  # ConsoleSMSBackend logs "SMS to <number>: <text with the code>" (iltiam-backend apps/notifications/sms.py).
  compose logs --no-log-prefix --since 30m backend-web backend-worker 2>/dev/null | grep -E 'SMS to|WHATSAPP code to' | tail -n 10 \
    || echo "No sign-in codes logged in the last 30 minutes."
}

main() {
  local cmd="${1:-help}"
  [ $# -gt 0 ] && shift
  case "$cmd" in
    up) cmd_up "$@" ;;
    reset) cmd_reset "$@" ;;
    seed) seed --reset ;;
    smoke) cmd_smoke ;;
    codes) cmd_codes ;;
    status) compose ps ;;
    logs) compose logs --tail 100 "$@" ;;
    down)
      if [ "${1:-}" = --volumes ]; then compose down -v --remove-orphans; else compose down --remove-orphans; fi ;;
    compose) compose "$@" ;;
    help | -h | --help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0" ;;
    *) die "unknown command $cmd (scripts/dev.sh help)" ;;
  esac
}

main "$@"
