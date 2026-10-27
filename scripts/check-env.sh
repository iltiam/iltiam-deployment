#!/usr/bin/env bash
# Check the env templates and scripts without any real secret (issue #3). CI and a laptop run the same thing.
# Runbook: docs/runbooks/04-secrets.md, section 10.
#
#   1. Lint every env/*.env.example (scripts/render-env.sh refuses a malformed template).
#   2. scripts/bootstrap-secrets.sh prints values of the right shape (they are checked, never shown).
#   3. Render staging and production with dummy values, then `docker compose config --quiet` against
#      ci/env-check.compose.yml (replaced by the real compose.yml in #2).
#   4. Negative cases: what must be refused is refused.
#
# Usage: bash scripts/check-env.sh
# Needs bash, openssl and the Docker Compose plugin. No image is pulled and no container started.
# Prints names and results only, never a value: CI logs of this repository are public.

set -euo pipefail

cd "$(dirname "$0")/.."

RENDER=scripts/render-env.sh
COMPOSE_FILE=ci/env-check.compose.yml
TEMPLATES=(env/backend.env.example env/ai.env.example env/web.env.example env/infra.env.example)
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

# Render all four templates into a directory.
render_all() {
  local env="$1" dir="$2" template
  mkdir -p "$dir"
  for template in "${TEMPLATES[@]}"; do
    bash "$RENDER" "$env" "$template" "$dir/$(basename "${template%.example}")" >/dev/null || return 1
  done
}

compose_config() {
  local env="$1" dir="$2"
  shift 2
  ENV_DIR="$(native "$dir")" docker compose -f "$COMPOSE_FILE" -p "iltiam-check-$env" \
    --env-file "$(native "$dir/infra.env")" config "$@"
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
  ok "4 env files rendered"
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

# --- 4. Negative cases -----------------------------------------------------------------------------------------------

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
[[ ! -e "$work/neg-1.env" && ! -e "$work/neg-2.env" && ! -e "$work/neg-3.env" ]] \
  || fail "a refused render still wrote its output file"
ok "a refused render writes no file"

log "all checks passed"
