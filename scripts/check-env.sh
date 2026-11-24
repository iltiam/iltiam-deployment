#!/usr/bin/env bash
# Check the env templates and scripts without any real secret (issue #3). CI and a laptop run the same thing.
# Runbook: docs/runbooks/04-secrets.md, section 10.
#
#   1. Lint every env/*.env.example (scripts/render-env.sh refuses a malformed template).
#   2. scripts/bootstrap-secrets.sh prints values of the right shape (they are checked, never shown).
#   3. Render staging and production with dummy values, then `docker compose config --quiet` against compose.yml
#      (Runbook 5, #2) with env/<env>.versions and every profile on.
#   4. scripts/render-deploy-env.sh, as the deploy workflows run it: from JSON or from DEPLOY_SECRET_<NAME>
#      variables, the files each environment needs.
#   5. Negative cases: what must be refused is refused.
#   6. The Authentica names (Runbook 12): the key stays a secret, the sender name a variable, staging runs without them.
#   7. The web's ILTIAM_ENVIRONMENT (iltiam-web#63).
#   8. Automatic staging deploys (Runbook 9): set-version.sh on a copy of the repository, and what the backup, health
#      check and remote-deploy scripts refuse before they reach the VM.
#   9. Backups (Runbook 6, #8): staging deploys without the backup settings, production doesn't; backup.env is read
#      as data; object names, the status file, what the backup scripts refuse; no workflow touches a dump.
#
# Usage: bash scripts/check-env.sh
# Needs bash, openssl, jq and the Docker Compose plugin. No image is pulled and no container started.
# The structural rules of compose.yml (networks, ports, limits) are scripts/check-compose.sh.
# Prints names and results only, never a value: CI logs of this repository are public.

set -euo pipefail

cd "$(dirname "$0")/.."

RENDER=scripts/render-env.sh
COMPOSE_FILE=compose.yml
TEMPLATES=(env/backend.env.example env/ai.env.example env/web.env.example env/infra.env.example env/backup.env.example)
# A dummy with a `$` in it: Compose must keep it literal, not interpolate it.
# shellcheck disable=SC2016  # the `$` is meant literally
DOLLAR_DUMMY='dummy$literal-value'

log() { printf '\n==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Docker Compose on Windows is a Windows program: hand it C:/... paths, not Git Bash's /tmp/...
native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# Every variable name the templates take in an environment.
names_for() {
  local template
  for template in "${TEMPLATES[@]}"; do bash "$RENDER" --list "$1" "$template"; done | awk '{print $3}' | sort -u
}

# Export a dummy for every name the environment takes, except the names given after the environment.
export_dummies() {
  local env="$1" name skip
  shift
  while read -r name; do
    for skip in "$@"; do [[ "$name" == "$skip" ]] && continue 2; done
    export "$name=dummy-$env-${name,,}"
  done < <(names_for "$env")
}

# Render all the templates into a directory.
render_all() {
  local env="$1" dir="$2" template
  mkdir -p "$dir"
  for template in "${TEMPLATES[@]}"; do
    bash "$RENDER" "$env" "$template" "$dir/$(basename "${template%.example}")" >/dev/null || return 1
  done
}

# The real compose.yml, with every profile on so each env file is read (production's versions file leaves them all
# off). ENV_DIR and DATA_DIR come from the shell; interpolation from infra.env and the versions file only.
compose_config() {
  local env="$1" dir="$2"
  shift 2
  COMPOSE_PROFILES=backend,web ENV_DIR="$(native "$dir")" DATA_DIR="$(native "$work/data-$env")" ILTIAM_ENV="$env" \
    docker compose -f "$COMPOSE_FILE" -p "iltiam-check-$env" \
    --env-file "$(native "$dir/infra.env")" --env-file "env/$env.versions" config "$@"
}

# Run a command that must fail; its own error output is hidden.
expect_fail() {
  local what="$1"
  shift
  if ("$@") >/dev/null 2>&1; then fail "not refused: $what"; fi
  ok "refused: $what"
}

# --- 1. Templates -------------------------------------------------------------------------------------------------

log "templates"
declare -A kind_of=()
for template in "${TEMPLATES[@]}"; do
  [[ -f "$template" ]] || fail "missing $template"
  listed="$(bash "$RENDER" --list staging "$template")" || fail "$template is malformed (see the error above)"
  [[ -n "$listed" ]] || fail "$template has no variables"
  while read -r kind _ name; do
    if [[ -n "${kind_of[$name]:-}" && "${kind_of[$name]}" != "$kind" ]]; then
      fail "$name is '${kind_of[$name]}' in one template and '$kind' in another"
    fi
    kind_of[$name]="$kind"
  done <<<"$listed"
  ok "$template: $(wc -l <<<"$listed" | tr -d ' ') variables, each tagged, no values"
done
if grep -q '^# secret' env/web.env.example; then
  fail "env/web.env.example must hold no secret (every browser sees all of it)"
fi
ok "web.env holds no secret"

# --- 2. bootstrap-secrets.sh --------------------------------------------------------------------------------------

log "bootstrap-secrets.sh"
first="$(bash scripts/bootstrap-secrets.sh staging 2>/dev/null)" || fail "bootstrap-secrets.sh staging failed"
second="$(bash scripts/bootstrap-secrets.sh production 2>/dev/null)" || fail "bootstrap-secrets.sh production failed"
declare -A shape=(
  [SECRET_KEY]='^[0-9a-f]{64}$' [JWT_SECRET_KEY]='^[0-9a-f]{64}$' [AI_SERVICE_TOKEN]='^[0-9a-f]{64}$'
  [DJANGO_SECRET_KEY]='^[0-9a-f]{64}$' [FIELD_ENCRYPTION_KEY]='^[A-Za-z0-9_-]{43}=$'
  [POSTGRES_PASSWORD]='^[0-9a-f]{48}$' [BACKEND_DB_PASSWORD]='^[0-9a-f]{48}$' [AI_DB_PASSWORD]='^[0-9a-f]{48}$'
)
for name in "${!shape[@]}"; do
  [[ "$(grep -c "^$name=" <<<"$first")" == 1 ]] || fail "bootstrap-secrets.sh must print $name exactly once"
  value="$(grep "^$name=" <<<"$first" | cut -d= -f2-)"
  [[ "$value" =~ ${shape[$name]} ]] || fail "bootstrap-secrets.sh: $name has the wrong shape"
  [[ "$value" != "$(grep "^$name=" <<<"$second" | cut -d= -f2-)" ]] || fail "bootstrap-secrets.sh repeated $name"
  [[ "${kind_of[$name]:-}" == secret ]] || fail "$name is printed by bootstrap-secrets.sh but no template has it as a secret"
done
unset first second value
ok "${#shape[@]} values of the right shape, different on every run, all secrets in the templates"

# --- 3. Dummy render and docker compose config ---------------------------------------------------------------------

for env in staging production; do
  log "render $env with dummies, docker compose config"
  # A subshell, so the dummies are not in the environment `docker compose` runs in below: there, infra.env
  # alone must supply what compose interpolates.
  (
    export_dummies "$env"
    # shellcheck disable=SC2030  # staying inside the subshell is the point
    export SECRET_KEY="$DOLLAR_DUMMY"
    render_all "$env" "$work/$env"
  ) || fail "rendering $env failed (see the error above)"
  for file in "$work/$env"/*.env; do
    grep -Eq "^[A-Z][A-Z0-9_]*='" "$file" || fail "$file: no quoted NAME='value' lines"
  done
  ok "${#TEMPLATES[@]} env files rendered"
  if [[ "$env" == production ]]; then
    ! grep -Eq '^(OTP_DEV_ECHO_NUMBERS|STAGING_TEST_PASSWORD|DEMO_SEED_ENABLED)=' "$work/$env/backend.env" \
      || fail "a staging-only variable reached the production backend.env"
    ok "no staging-only variable in production"
  fi
  compose_config "$env" "$work/$env" --quiet || fail "docker compose config failed for $env"
  ok "docker compose config"
  # Compose escapes a literal `$` as `$$` in its output; an interpolated one would have vanished.
  # shellcheck disable=SC2016  # the `$$` is meant literally
  compose_config "$env" "$work/$env" --format json 2>/dev/null | grep -qF 'dummy$$literal-value' \
    || fail "Compose interpolated a \$ inside a quoted value"
  ok "a \$ inside a value stays literal"
done

# --- 4. render-deploy-env.sh -----------------------------------------------------------------------------------------

# SECRETS_JSON or VARS_JSON as the deploy workflow gets them (toJSON(secrets), toJSON(vars)): every name of one kind
# that the environment takes, with a dummy value.
deploy_json() {
  local env="$1" kind="$2" template k name args=()
  for template in "${TEMPLATES[@]}"; do
    while read -r k _ name; do
      if [[ "$k" == "$kind" ]]; then args+=(--arg "$name" "dummy-$env-${name,,}"); fi
    done < <(bash "$RENDER" --list "$env" "$template")
  done
  jq -cn '$ARGS.named' "${args[@]}" | tr -d '\r'
}

log "render-deploy-env.sh (the deploy workflow's renderer)"
command -v jq >/dev/null 2>&1 || fail "jq not found"
for env in staging production; do
  profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' "env/$env.versions" | tr -d '\r' | tail -n 1)"
  expected="ai.env"
  if [[ ",$profiles," == *",backend,"* ]]; then expected+=" backend.env"; fi
  expected+=" backup.env infra.env"
  if [[ ",$profiles," == *",web,"* ]]; then expected+=" web.env"; fi
  secrets_json="$(deploy_json "$env" secret)"
  vars_json="$(deploy_json "$env" var)"
  SECRETS_JSON="$secrets_json" VARS_JSON="$vars_json" \
    bash scripts/render-deploy-env.sh "$env" "$work/deploy-$env" >/dev/null || fail "render-deploy-env.sh $env failed"
  got="$(cd "$work/deploy-$env" && printf '%s ' *)"
  [[ "${got% }" == "$expected" ]] || fail "render-deploy-env.sh $env wrote '$got', expected '$expected'"
  ok "$env: $expected (versions file: profiles '$profiles')"
done
# The backend profile alone, from a copy of the repository: backend.env, no web.env.
mkdir -p "$work/repo-backend"
cp -r scripts env "$work/repo-backend/"
sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=backend/' "$work/repo-backend/env/staging.versions"
SECRETS_JSON="$(deploy_json staging secret)" VARS_JSON="$(deploy_json staging var)" \
  bash "$work/repo-backend/scripts/render-deploy-env.sh" staging "$work/deploy-backend" >/dev/null \
  || fail "render-deploy-env.sh staging with the backend profile on failed"
got="$(cd "$work/deploy-backend" && printf '%s ' *)"
[[ "${got% }" == "ai.env backend.env backup.env infra.env" ]] \
  || fail "render-deploy-env.sh with the backend profile on wrote '$got', expected 'ai.env backend.env backup.env infra.env'"
ok "staging, backend profile alone: ai.env backend.env backup.env infra.env"
# The web profile alone, from another copy: web.env, no backend.env.
mkdir -p "$work/repo-web"
cp -r scripts env "$work/repo-web/"
sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=web/' "$work/repo-web/env/staging.versions"
SECRETS_JSON="$(deploy_json staging secret)" VARS_JSON="$(deploy_json staging var)" \
  bash "$work/repo-web/scripts/render-deploy-env.sh" staging "$work/deploy-web" >/dev/null \
  || fail "render-deploy-env.sh staging with the web profile on failed"
got="$(cd "$work/deploy-web" && printf '%s ' *)"
[[ "${got% }" == "ai.env backup.env infra.env web.env" ]] \
  || fail "render-deploy-env.sh with the web profile on wrote '$got', expected 'ai.env backup.env infra.env web.env'"
ok "staging, web profile alone: ai.env backup.env infra.env web.env"
secrets_json="$(deploy_json staging secret | jq -c '. + {FCM_SERVICE_ACCOUNT_JSON: "{\"type\": \"service_account\"}"}' | tr -d '\r')"
SECRETS_JSON="$secrets_json" VARS_JSON="$(deploy_json staging var)" \
  bash scripts/render-deploy-env.sh staging "$work/deploy-fcm" >/dev/null || fail "render-deploy-env.sh with FCM failed"
[[ -s "$work/deploy-fcm/fcm-service-account.json" ]] || fail "FCM_SERVICE_ACCOUNT_JSON did not become a file"
ok "FCM_SERVICE_ACCOUNT_JSON becomes fcm-service-account.json"
# The workflows' way: each secret as DEPLOY_SECRET_<NAME> (never toJSON(secrets)). The same files, byte for byte, as
# from SECRETS_JSON, and the DEPLOY_SECRET_ copies are gone before render-env.sh runs.
from_named_vars() {
  local name value
  while IFS=$'\t' read -r name value; do
    export "DEPLOY_SECRET_$name=$value"
  done < <(jq -r 'to_entries[] | [.key, .value] | @tsv' <<<"$secrets_json" | tr -d '\r')
  VARS_JSON="$(deploy_json staging var)" bash scripts/render-deploy-env.sh staging "$work/deploy-named" >/dev/null
}
(from_named_vars) || fail "render-deploy-env.sh from DEPLOY_SECRET_ variables failed"
diff -rq "$work/deploy-fcm" "$work/deploy-named" >/dev/null \
  || fail "DEPLOY_SECRET_ variables and SECRETS_JSON rendered different files"
ok "DEPLOY_SECRET_<NAME> variables render the same files as SECRETS_JSON"
unset secrets_json vars_json

# --- 5. Negative cases -----------------------------------------------------------------------------------------------

log "negative cases"
# expect_fail runs each of these in a subshell, so their exports don't leak into the checks after them.
missing_required() {
  export_dummies staging SECRET_KEY
  bash "$RENDER" staging env/backend.env.example "$work/neg-1.env"
}
staging_only_in_production() {
  export_dummies production
  export OTP_DEV_ECHO_NUMBERS=+966599999001
  bash "$RENDER" production env/backend.env.example "$work/neg-2.env"
}
single_quote_in_value() {
  export_dummies staging
  # shellcheck disable=SC2031  # expect_fail runs this in its own subshell on purpose
  export SECRET_KEY="it's"
  bash "$RENDER" staging env/backend.env.example "$work/neg-3.env"
}
expect_fail "a required variable left unset (SECRET_KEY)" missing_required
expect_fail "a production render with OTP_DEV_ECHO_NUMBERS set" staging_only_in_production
expect_fail "a value containing a single quote" single_quote_in_value
printf '# var, required: test\nFOO=bar\n' >"$work/with-value.env.example"
expect_fail "a template with a value in it" bash "$RENDER" --list staging "$work/with-value.env.example"
printf '# a comment\nFOO=\n' >"$work/untagged.env.example"
expect_fail "a template variable without its tag line" bash "$RENDER" --list staging "$work/untagged.env.example"
mkdir -p "$work/no-tunnel"
cp "$work/staging"/*.env "$work/no-tunnel/"
grep -v '^CF_TUNNEL_TOKEN=' "$work/staging/infra.env" >"$work/no-tunnel/infra.env"
expect_fail "docker compose config with CF_TUNNEL_TOKEN missing from infra.env" \
  compose_config staging "$work/no-tunnel" --quiet
# AI_SERVICE_TOKEN: required in ai.env, which every deploy writes, whatever the profiles.
deploy_without_service_token() {
  SECRETS_JSON="$(deploy_json staging secret | jq -c 'del(.AI_SERVICE_TOKEN)' | tr -d '\r')" \
    VARS_JSON="$(deploy_json staging var)" bash scripts/render-deploy-env.sh staging "$work/neg-deploy"
}
expect_fail "render-deploy-env.sh with AI_SERVICE_TOKEN missing from the Environment" deploy_without_service_token
# The workflows' way: a secret that isn't set in the Environment arrives as an empty DEPLOY_SECRET_ variable.
deploy_named_empty_service_token() {
  local name value
  while IFS=$'\t' read -r name value; do
    export "DEPLOY_SECRET_$name=$value"
  done < <(deploy_json staging secret | jq -r 'to_entries[] | [.key, .value] | @tsv' | tr -d '\r')
  export DEPLOY_SECRET_AI_SERVICE_TOKEN=""
  VARS_JSON="$(deploy_json staging var)" bash scripts/render-deploy-env.sh staging "$work/neg-named"
}
expect_fail "render-deploy-env.sh with DEPLOY_SECRET_AI_SERVICE_TOKEN empty" deploy_named_empty_service_token
deploy_no_secrets() {
  VARS_JSON="$(deploy_json staging var)" bash scripts/render-deploy-env.sh staging "$work/neg-none"
}
expect_fail "render-deploy-env.sh with neither SECRETS_JSON nor DEPLOY_SECRET_ variables" deploy_no_secrets
# web.env's two values the image can't start without, with the web profile on.
deploy_without_web_var() {
  SECRETS_JSON="$(deploy_json staging secret)" \
    VARS_JSON="$(deploy_json staging var | jq -c --arg name "$1" 'del(.[$name])' | tr -d '\r')" \
    bash "$work/repo-web/scripts/render-deploy-env.sh" staging "$work/neg-web"
}
expect_fail "render-deploy-env.sh with API_BASE_URL missing, web profile on" deploy_without_web_var API_BASE_URL
expect_fail "render-deploy-env.sh with IMAGE_ORIGINS missing, web profile on" deploy_without_web_var IMAGE_ORIGINS
bad_fcm() {
  SECRETS_JSON="$(deploy_json staging secret | jq -c '. + {FCM_SERVICE_ACCOUNT_JSON: "not json"}' | tr -d '\r')" \
    VARS_JSON="$(deploy_json staging var)" bash scripts/render-deploy-env.sh staging "$work/neg-fcm"
}
expect_fail "render-deploy-env.sh with an FCM secret that is not JSON" bad_fcm
[[ ! -e "$work/neg-1.env" && ! -e "$work/neg-2.env" && ! -e "$work/neg-3.env" ]] \
  || fail "a refused render still wrote its output file"
ok "a refused render writes no file"

# --- 6. Authentica (Runbook 12) --------------------------------------------------------------------------------------

# Only names the published backend image reads. iltiam-backend#103 added the code mode and the two template ids.
log "Authentica names"
declare -A authentica_kind=([AUTHENTICA_API_KEY]=secret [AUTHENTICA_SENDER_NAME]=var [SMS_BACKEND]=var
  [AUTHENTICA_SMS_CODE_MODE]=var [AUTHENTICA_SMS_TEMPLATE_ID_AR]=var [AUTHENTICA_SMS_TEMPLATE_ID_EN]=var)
for name in "${!authentica_kind[@]}"; do
  [[ "${kind_of[$name]:-}" == "${authentica_kind[$name]}" ]] \
    || fail "$name must be a '${authentica_kind[$name]}' in env/backend.env.example, got '${kind_of[$name]:-nothing}'"
done
ok "the key is a secret; the sender name, SMS_BACKEND and the #103 settings are variables"
# Optional, so production (send_sms, the backend's default) leaves them out, and an empty template id never reaches
# env.int.
production_backend="$(bash "$RENDER" --list production env/backend.env.example | tr -d '\r')"
for name in AUTHENTICA_SMS_CODE_MODE AUTHENTICA_SMS_TEMPLATE_ID_AR AUTHENTICA_SMS_TEMPLATE_ID_EN; do
  grep -qx "var may $name" <<<"$production_backend" || fail "$name must be '# var, optional:' in env/backend.env.example"
done
ok "the #103 settings are optional"
# The renderer copies only listed names: staging's send_otp settings must reach backend.env.
VARS_JSON="$(deploy_json staging var | jq -c '. + {AUTHENTICA_SMS_CODE_MODE: "send_otp",
    AUTHENTICA_SMS_TEMPLATE_ID_AR: "8", AUTHENTICA_SMS_TEMPLATE_ID_EN: "7"}' | tr -d '\r')" \
  SECRETS_JSON="$(deploy_json staging secret)" bash scripts/render-deploy-env.sh staging "$work/deploy-send-otp" >/dev/null \
  || fail "render-deploy-env.sh with the send_otp settings failed"
for line in "AUTHENTICA_SMS_CODE_MODE='send_otp'" "AUTHENTICA_SMS_TEMPLATE_ID_AR='8'" "AUTHENTICA_SMS_TEMPLATE_ID_EN='7'"; do
  grep -qx "$line" "$work/deploy-send-otp/backend.env" || fail "$line did not reach staging's backend.env"
done
ok "staging's send_otp settings reach backend.env"
# Staging can still render with no SMS_BACKEND and no sender name (console delivery, before Authentica is on).
staging_without_sms() {
  export_dummies staging SMS_BACKEND AUTHENTICA_API_KEY AUTHENTICA_SENDER_NAME
  bash "$RENDER" staging env/backend.env.example "$work/staging-no-sms.env" >/dev/null
}
(staging_without_sms) || fail "staging must render without SMS_BACKEND, AUTHENTICA_API_KEY and AUTHENTICA_SENDER_NAME"
! grep -Eq '^(SMS_BACKEND|AUTHENTICA_API_KEY|AUTHENTICA_SENDER_NAME)=' "$work/staging-no-sms.env" \
  || fail "an unset Authentica name still reached staging's backend.env"
ok "staging renders without them, and leaves them out"
production_without_key() {
  export_dummies production AUTHENTICA_API_KEY
  bash "$RENDER" production env/backend.env.example "$work/neg-4.env"
}
expect_fail "a production render with AUTHENTICA_API_KEY unset" production_without_key
# The trap in the issue's wording: a sender name saved as a secret never reaches backend.env.
SECRETS_JSON="$(deploy_json staging secret | jq -c '. + {AUTHENTICA_SENDER_NAME: "dummy-sender"}' | tr -d '\r')" \
  VARS_JSON="$(deploy_json staging var | jq -c 'del(.AUTHENTICA_SENDER_NAME)' | tr -d '\r')" \
  bash scripts/render-deploy-env.sh staging "$work/deploy-sender-secret" >/dev/null \
  || fail "render-deploy-env.sh with the sender name saved as a secret failed"
! grep -q '^AUTHENTICA_SENDER_NAME=' "$work/deploy-sender-secret/backend.env" \
  || fail "a sender name saved as a secret reached backend.env; the renderer must read a var from variables only"
ok "a sender name saved as a secret is ignored: it must be a variable"

# --- 7. Web environment (iltiam/iltiam-web#63) ----------------------------------------------------------------------

# Optional: the image treats an unset ILTIAM_ENVIRONMENT as production. Staging sets it, so the code step shows the
# backend's test code; the renderer copies only listed names.
log "ILTIAM_ENVIRONMENT"
production_web="$(bash "$RENDER" --list production env/web.env.example | tr -d '\r')"
grep -qx 'var may ILTIAM_ENVIRONMENT' <<<"$production_web" \
  || fail "ILTIAM_ENVIRONMENT must be '# var, optional:' in env/web.env.example"
VARS_JSON="$(deploy_json staging var | jq -c '. + {ILTIAM_ENVIRONMENT: "staging"}' | tr -d '\r')" \
  SECRETS_JSON="$(deploy_json staging secret)" \
  bash "$work/repo-web/scripts/render-deploy-env.sh" staging "$work/deploy-web-env" >/dev/null \
  || fail "render-deploy-env.sh with ILTIAM_ENVIRONMENT set failed"
grep -qx "ILTIAM_ENVIRONMENT='staging'" "$work/deploy-web-env/web.env" \
  || fail "ILTIAM_ENVIRONMENT did not reach staging's web.env"
ok "it is optional, and staging's value reaches web.env"

# --- 8. Automatic staging deploys (Runbook 9, issue #16) -----------------------------------------------------------

# On a copy of the repository: set-version.sh changes only the named service's lines and keeps the file valid.
log "set-version.sh and the automatic deploy's guards"
auto="$work/repo-auto"
mkdir -p "$auto"
cp -r scripts env "$auto/"
versions="$auto/env/staging.versions"
before="$(cat "$versions")"
sha_a=1111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
sha_b=2222222bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
out="$(bash "$auto/scripts/set-version.sh" staging web "$sha_a")" || fail "set-version.sh staging web failed"
grep -qx 'changed=true' <<<"$out" || fail "set-version.sh web: expected changed=true"
grep -qx 'tag=sha-1111111' <<<"$out" || fail "set-version.sh web: expected tag=sha-1111111"
grep -qx "previous=$(sed -n 's/^WEB_IMAGE=.*://p' <<<"$before")" <<<"$out" || fail "set-version.sh web: wrong previous tag"
grep -qx 'WEB_IMAGE=ghcr.io/iltiam/iltiam-web:sha-1111111' "$versions" || fail "set-version.sh did not set WEB_IMAGE"
for key in COMPOSE_PROFILES AI_API_IMAGE AI_WORKER_IMAGE BACKEND_IMAGE; do
  [[ "$(grep "^$key=" "$versions")" == "$(grep "^$key=" <<<"$before")" ]] || fail "set-version.sh web changed $key"
done
[[ "$(grep -B1 '^WEB_IMAGE=' "$versions" | head -n 1)" == "# sha-1111111: iltiam-web main, commit $sha_a;"* ]] \
  || fail "set-version.sh web: the line above WEB_IMAGE must name the commit"
[[ "$(grep -c "^# sha-1111111" "$versions")" == 1 && "$(grep -B2 '^WEB_IMAGE=' "$versions" | head -n 1)" != \#* ]] \
  || fail "set-version.sh web: the old comment above WEB_IMAGE must be replaced, not kept"
bash "$auto/scripts/deploy.sh" --check-versions staging >/dev/null || fail "the versions file is invalid after set-version.sh"
ok "web: only WEB_IMAGE and its comment change, the file stays valid"
snapshot="$(cat "$versions")"
out="$(bash "$auto/scripts/set-version.sh" staging web "$sha_a")" || fail "set-version.sh web, same tag, failed"
grep -qx 'changed=false' <<<"$out" || fail "set-version.sh with the running tag: expected changed=false"
[[ "$(cat "$versions")" == "$snapshot" ]] || fail "set-version.sh with the running tag changed the file"
ok "the same tag again: changed=false, file untouched"
bash "$auto/scripts/set-version.sh" staging ai "$sha_b" >/dev/null || fail "set-version.sh staging ai failed"
grep -qx 'AI_API_IMAGE=ghcr.io/iltiam/iltiam-ai-api:sha-2222222' "$versions" || fail "set-version.sh ai: AI_API_IMAGE"
grep -qx 'AI_WORKER_IMAGE=ghcr.io/iltiam/iltiam-ai-worker:sha-2222222' "$versions" || fail "set-version.sh ai: AI_WORKER_IMAGE"
grep -qx 'WEB_IMAGE=ghcr.io/iltiam/iltiam-web:sha-1111111' "$versions" || fail "set-version.sh ai changed WEB_IMAGE"
bash "$auto/scripts/deploy.sh" --check-versions staging >/dev/null || fail "the versions file is invalid after set-version.sh ai"
ok "ai: both AI images get the same tag, the file stays valid"
bash "$auto/scripts/set-version.sh" staging backend "$sha_b" >/dev/null || fail "set-version.sh staging backend failed"
grep -qx 'BACKEND_IMAGE=ghcr.io/iltiam/iltiam-backend:sha-2222222' "$versions" || fail "set-version.sh backend"
ok "backend: BACKEND_IMAGE"
# The automatic deploy (auto-deploy-staging.yml): --auto words the comment, --tag writes the base commit's tags.
bash "$auto/scripts/set-version.sh" --auto staging web "$sha_b" >/dev/null || fail "set-version.sh --auto failed"
[[ "$(grep -B1 '^WEB_IMAGE=' "$versions" | head -n 1)" == "# sha-2222222: iltiam-web main, commit $sha_b; deployed automatically"* ]] \
  || fail "set-version.sh --auto: the line above WEB_IMAGE must say it was deployed automatically"
out="$(bash "$auto/scripts/set-version.sh" --auto staging web --tag sha-1111111)" || fail "set-version.sh --tag failed"
for expected_line in changed=true previous=sha-2222222 tag=sha-1111111; do
  grep -qx "$expected_line" <<<"$out" || fail "set-version.sh --tag: expected $expected_line"
done
grep -qx 'WEB_IMAGE=ghcr.io/iltiam/iltiam-web:sha-1111111' "$versions" || fail "set-version.sh --tag did not set WEB_IMAGE"
[[ "$(grep -B1 '^WEB_IMAGE=' "$versions" | head -n 1)" == "# sha-1111111: iltiam-web, what staging ran on "* ]] \
  || fail "set-version.sh --tag: the line above WEB_IMAGE must say it is what staging ran"
bash "$auto/scripts/set-version.sh" staging ai --tag 1.2.3 >/dev/null || fail "set-version.sh --tag X.Y.Z failed"
grep -qx 'AI_WORKER_IMAGE=ghcr.io/iltiam/iltiam-ai-worker:1.2.3' "$versions" || fail "set-version.sh --tag ai: AI_WORKER_IMAGE"
bash "$auto/scripts/deploy.sh" --check-versions staging >/dev/null || fail "the versions file is invalid after --tag"
ok "--auto and --tag (sha-<7> and X.Y.Z): the right lines and comments, the file stays valid"
expect_fail "set-version.sh --tag latest" bash "$auto/scripts/set-version.sh" staging web --tag latest
expect_fail "set-version.sh --tag with a shell character" bash "$auto/scripts/set-version.sh" staging web --tag 'sha-1;x'
expect_fail "set-version.sh for production" bash "$auto/scripts/set-version.sh" production web "$sha_a"
expect_fail "set-version.sh with a short commit hash" bash "$auto/scripts/set-version.sh" staging web 1111111
expect_fail "set-version.sh with an unknown service" bash "$auto/scripts/set-version.sh" staging mobile "$sha_a"
sed -i 's#^WEB_IMAGE=.*#WEB_IMAGE=ghcr.io/someone/else:sha-1111111#' "$versions"
expect_fail "set-version.sh over an unexpected image name" bash "$auto/scripts/set-version.sh" staging web "$sha_b"
# The other scripts refuse before they touch the VM (no SSH, no Docker here).
expect_fail "pre-deploy-backup.sh for production" bash scripts/pre-deploy-backup.sh production backend-sha-1111111
expect_fail "pre-deploy-backup.sh with a malformed label" bash scripts/pre-deploy-backup.sh staging 'backend-sha-1;x'
expect_fail "health-check.sh for production" bash scripts/health-check.sh production web
expect_fail "health-check.sh for an unknown service" bash scripts/health-check.sh staging mobile
expect_fail "remote-deploy.sh --backup for production" bash scripts/remote-deploy.sh --backup production backend-sha-1111111
expect_fail "remote-deploy.sh --backup with a malformed label" bash scripts/remote-deploy.sh --backup staging 'x;y'
expect_fail "remote-deploy.sh --check for an unknown service" env DEPLOY_HOST=h DEPLOY_SHA="$sha_a" \
  bash scripts/remote-deploy.sh --check staging 'web;x'
expect_fail "remote-deploy.sh --status for production" env DEPLOY_HOST=h bash scripts/remote-deploy.sh --status production
expect_fail "remote-deploy.sh --status with an extra argument" env DEPLOY_HOST=h \
  bash scripts/remote-deploy.sh --status staging web
expect_fail "remote-deploy.sh --status without DEPLOY_HOST" env -u DEPLOY_HOST bash scripts/remote-deploy.sh --status staging
unset auto versions before snapshot out sha_a sha_b expected_line
# #16: a script that bash reads from SSH's stdin ends early when one of its commands reads stdin. remote-deploy.sh
# copies the backup script to a file first; the backup's docker compose commands read nothing from stdin.
! grep -Eq 'bash[[:space:]]+(-s|/dev/stdin)' scripts/remote-deploy.sh \
  || fail "remote-deploy.sh must not run a script from SSH's stdin (copy it to a file first, #16)"
! grep -E 'compose (exec|run)' scripts/pre-deploy-backup.sh | grep -v '^[[:space:]]*#' | grep -qv '</dev/null' \
  || fail "every compose exec/run in pre-deploy-backup.sh needs </dev/null (#16)"
ok "no script runs from SSH's stdin; the backup's compose commands read no stdin"

# --- 9. Backups (Runbook 6, issue #8) --------------------------------------------------------------------------------

log "backups (Runbook 6)"
# Staging deploys keep working before Runbook 6 is done: backup.env is written, with none of the backup names.
no_backup_secrets="$(deploy_json staging secret | jq -c 'with_entries(select(.key | startswith("BACKUP_") | not))' | tr -d '\r')"
SECRETS_JSON="$no_backup_secrets" VARS_JSON="$(deploy_json staging var | jq -c 'del(.BACKUP_AGE_RECIPIENT)' | tr -d '\r')" \
  bash scripts/render-deploy-env.sh staging "$work/deploy-no-backup" >/dev/null \
  || fail "a staging deploy without any backup setting failed"
[[ -f "$work/deploy-no-backup/backup.env" ]] || fail "a staging deploy without backup settings wrote no backup.env"
! grep -q '^BACKUP_' "$work/deploy-no-backup/backup.env" || fail "an unset backup name reached staging's backup.env"
ok "staging deploys without the backup settings; backup.env then holds none of them"
production_without_age_key() {
  SECRETS_JSON="$(deploy_json production secret | jq -c 'del(.BACKUP_AGE_IDENTITY)' | tr -d '\r')" \
    VARS_JSON="$(deploy_json production var)" bash scripts/render-deploy-env.sh production "$work/neg-backup"
}
expect_fail "a production deploy without BACKUP_AGE_IDENTITY" production_without_age_key
unset no_backup_secrets

# backup.env is read as data, never run: the names it may hold, single-quoted, nothing else.
backup_lib() {
  # shellcheck disable=SC2030,SC2031  # each call is its own subshell on purpose
  export ILTIAM_ROOT="$work/backup-root"
  # shellcheck source=scripts/lib/backup-common.sh
  . scripts/lib/backup-common.sh
  backup_env_name staging
  "$@"
}
read_rendered() {
  backup_load_env "$work/deploy-staging/backup.env"
  [[ "$BACKUP_AGE_IDENTITY" == dummy-staging-backup_age_identity && "$STORAGE_REGION" == dummy-staging-storage_region ]]
}
(backup_lib read_rendered) || fail "the backup scripts can't read the backup.env render-deploy-env.sh writes"
ok "the backup scripts read the rendered backup.env"
mkdir -p "$work/backup-root/backups/status"
# shellcheck disable=SC2016  # the `$(...)` must stay literal: it is what the reader must refuse
printf '%s\n' 'BACKUP_PING_URL=$(touch '"$work"'/pwned)' >"$work/backup-code.env"
printf '%s\n' "PATH='/tmp'" >"$work/backup-other-name.env"
printf '%s\n' "BACKUP_PING_URL='a' # comment" >"$work/backup-trailing.env"
expect_fail "a backup.env line that is not NAME='value'" backup_lib backup_load_env "$work/backup-code.env"
[[ ! -e "$work/pwned" ]] || fail "reading backup.env ran a command from it"
expect_fail "a name in backup.env that is not a backup setting" backup_lib backup_load_env "$work/backup-other-name.env"
expect_fail "text after the quoted value in backup.env" backup_lib backup_load_env "$work/backup-trailing.env"
expect_fail "a missing backup setting" backup_lib backup_require BACKUP_AGE_IDENTITY

# Object names: <env>-<UTC time>.tar.age, and the time read back from them.
names_and_times() {
  local re
  re="$(backup_name_re staging)"
  [[ staging-20261123T023012Z.tar.age =~ $re ]] || return 1
  [[ ! production-20261123T023012Z.tar.age =~ $re ]] || return 1
  [[ ! staging-20261123T023012Z.tar.age.tmp =~ $re ]] || return 1
  [[ "$(backup_name_epoch staging-20261123T023012Z.tar.age)" == "$(date -u -d '2026-11-23 02:30:12' +%s)" ]] || return 1
  ! backup_name_epoch staging-latest.tar.age
}
(backup_lib names_and_times) || fail "backup object names or their times are read wrongly"
ok "object names: <env>-<UTC time>.tar.age, the time read back"

# The status file for Runbook 7 (#10): a failure keeps the time of the last success.
status_file() {
  local f="$BACKUP_DIR/status/staging-nightly.prom"
  backup_status nightly 1 1234
  grep -q '^iltiam_backup_last_success_timestamp_seconds{env="staging",job="nightly"} [0-9]*$' "$f" || return 1
  grep -qx 'iltiam_backup_last_size_bytes{env="staging"} 1234' "$f" || return 1
  backup_status nightly 0
  grep -qx 'iltiam_backup_last_run_success{env="staging",job="nightly"} 0' "$f" || return 1
  grep -q '^iltiam_backup_last_success_timestamp_seconds{env="staging",job="nightly"} [0-9]*$' "$f"
}
(backup_lib status_file) || fail "backup_status wrote a wrong status file"
ok "status file: success, size, and a failure that keeps the last success"

expect_fail "backup.sh for an unknown environment" bash scripts/backup.sh dev
expect_fail "backup.sh with an extra argument" bash scripts/backup.sh staging x
expect_fail "restore-test.sh for an unknown environment" bash scripts/restore-test.sh 'staging;x'
expect_fail "install-backup-timers.sh for an unknown environment" bash scripts/install-backup-timers.sh dev
expect_fail "backup-fetch.sh with a name of the other environment" bash scripts/backup-fetch.sh staging \
  production-20261123T023012Z.tar.age
expect_fail "backup-fetch.sh with a path in the name" bash scripts/backup-fetch.sh staging '../staging-20261123T023012Z.tar.age'
# docs/privacy/restore-location.md: dumps are made and restored on the VM only, never on a runner.
! grep -rnE 'pg_dump|pg_restore|scripts/backup\.sh|restore-test\.sh' .github/workflows/ >/dev/null || fail "a workflow dumps, restores or runs the backup scripts: they run on the VM only"
ok "no workflow dumps or restores a database"

log "all checks passed"
