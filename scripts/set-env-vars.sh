#!/usr/bin/env bash
# Set a GitHub Environment's VARIABLES from a reviewed file (issue #36): env/production.vars for production.
#
#   scripts/set-env-vars.sh <staging|production> <file>            dry run: what would change, nothing is written
#   scripts/set-env-vars.sh <staging|production> <file> --apply    set them (a person runs this, never an agent)
#
# Refuses any name the templates (env/*.env.example) mark as a secret, and any name no template knows: secrets go in
# with `gh secret set`, never through a file in this public repository. Skips TO-FILL and TO-DECIDE values. Variables
# are public by design, so the dry run prints their values; it never reads or prints a secret.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2

REPO="${REPO:-iltiam/iltiam-deployment}"
env_name="${1:-}"; file="${2:-}"; apply="${3:-}"
case "$env_name" in staging | production) ;; *) echo "usage: $0 <staging|production> <file> [--apply]" >&2; exit 2 ;; esac
[ -f "$file" ] || { echo "no file $file" >&2; exit 2; }
[ -z "$apply" ] || [ "$apply" = --apply ] || { echo "unknown option $apply" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "gh is not installed" >&2; exit 2; }

# kind of each name in the templates: "secret" or "var".
kinds="$(awk '/^# (secret|var),/ { k = ($2 == "secret,") ? "secret" : "var"; next }
              k != "" && /^[A-Z][A-Z0-9_]*=/ { sub(/=.*/, ""); print $0, k; k = ""; next }
              !/^#/ { k = "" }' env/*.env.example | sort -u)"
current="$(gh variable list --env "$env_name" -R "$REPO" --json name,value -q '.[] | "\(.name)=\(.value)"')"

bad=0 changes=0 to_set=()
while IFS= read -r line; do
  line="${line%$'\r'}"
  case "$line" in '' | '#'*) continue ;; esac
  name="${line%%=*}"; value="${line#*=}"
  kind="$(awk -v n="$name" '$1 == n { print $2 }' <<<"$kinds")"
  if [ "$kind" = secret ]; then echo "  REFUSED  $name is a secret in the templates: use gh secret set"; bad=1; continue; fi
  if [ -z "$kind" ]; then echo "  REFUSED  $name is in no template (env/*.env.example)"; bad=1; continue; fi
  case "$value" in TO-FILL | TO-DECIDE) echo "  skip     $name ($value)"; continue ;; esac
  now="$(sed -n "s/^$name=//p" <<<"$current")"
  if [ "$now" = "$value" ]; then echo "  same     $name"; continue; fi
  echo "  $([ -z "$now" ] && echo "add     " || echo "change  ") $name=$value"
  changes=$((changes + 1))
  to_set+=("$name=$value")
done <"$file"

# Nothing is written unless every line passed.
[ $bad = 0 ] || { echo "Fix the REFUSED lines first; nothing was set." >&2; exit 1; }
if [ "$apply" = --apply ]; then
  for line in "${to_set[@]}"; do
    gh variable set "${line%%=*}" --env "$env_name" --body "${line#*=}" -R "$REPO" >/dev/null
  done
  echo "Set $changes variable(s) in $env_name."
else echo "Dry run: $changes variable(s) would change in $env_name. Run again with --apply to set them."; fi
