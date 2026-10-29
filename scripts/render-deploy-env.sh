#!/usr/bin/env bash
# Render the env files one environment's deploy needs, from its GitHub Environment (deploy workflow, Runbook 5).
#
# Usage, in the deploy workflow only:
#   SECRETS_JSON='${{ toJSON(secrets) }}' VARS_JSON='${{ toJSON(vars) }}' \
#     bash scripts/render-deploy-env.sh <staging|production> <output directory>
#
# The secrets and variables arrive as two JSON objects in the environment, never as arguments. Only the names the
# templates in env/ list are taken from them; scripts/render-env.sh then writes each file (mode 600) and refuses a
# missing required value. The output directory gets:
#   infra.env, ai.env                always
#   backend.env                      when env/<env>.versions enables the backend profile
#   fcm-service-account.json         when the secret FCM_SERVICE_ACCOUNT_JSON is set (Runbook 11, DEP-13)
# web.env joins once compose.yml has the web service (WEB-03).
#
# Prints file names and counts only, never a value: the workflow's log is public.

set -euo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 && ("$1" == staging || "$1" == production) ]] \
  || die "usage: $0 <staging|production> <output directory>"
env_name="$1"
out="$2"
[[ -n "${SECRETS_JSON:-}" && -n "${VARS_JSON:-}" ]] || die "SECRETS_JSON and VARS_JSON must be set"
command -v jq >/dev/null 2>&1 || die "jq not found"

cd "$(dirname "$0")/.."

profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' "env/$env_name.versions" | tr -d '\r' | tail -n 1)"
templates=(env/infra.env.example env/ai.env.example)
if [[ ",$profiles," == *",backend,"* ]]; then
  templates+=(env/backend.env.example)
fi

# The value of NAME from SECRETS_JSON (kind secret) or VARS_JSON (kind var); empty when not set. jq reads the JSON
# straight from the environment, so it never passes through a file or an argument.
value_of() {
  local kind="$1" name="$2" source=VARS_JSON
  [[ "$kind" == secret ]] && source=SECRETS_JSON
  jq -rn --arg src "$source" --arg name "$name" '$ENV[$src] | fromjson | .[$name] // empty'
}

umask 077
mkdir -p "$out"
chmod 700 "$out"

for template in "${templates[@]}"; do
  # A subshell per file: each one sees only the names its own template lists.
  (
    while read -r kind _ name; do
      [[ -n "$name" ]] || continue
      value="$(value_of "$kind" "$name")"
      if [[ -n "$value" ]]; then export "$name=$value"; else unset "$name"; fi
    done < <(bash scripts/render-env.sh --list "$env_name" "$template")
    bash scripts/render-env.sh "$env_name" "$template" "$out/$(basename "${template%.example}")"
  ) || die "rendering $template for $env_name failed (see above; Runbook 4, section 10.2 lists what is missing)"
done

fcm="$(value_of secret FCM_SERVICE_ACCOUNT_JSON)"
if [[ -n "$fcm" ]]; then
  printf '%s\n' "$fcm" >"$out/fcm-service-account.json"
  jq -e 'type == "object"' "$out/fcm-service-account.json" >/dev/null \
    || die "FCM_SERVICE_ACCOUNT_JSON is not a JSON object (docs/secrets.md, section 6.5)"
  printf 'wrote %s\n' "$out/fcm-service-account.json"
fi
unset fcm
