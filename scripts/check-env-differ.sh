#!/usr/bin/env bash
# Go-live check (issue #23, docs/go-live-checklist.md): no secret has the same value in staging and production.
# Runbook 4 rule 3: "Staging and production never share a value."
#
#   scripts/check-env-differ.sh            on the VM as deploy, from the clone: compares /srv/iltiam/env/staging/*.env
#                                          with /srv/iltiam/env/production/*.env
#   ILTIAM_ROOT=<dir> scripts/check-env-differ.sh   the same under another root (tests)
#
# Which names are secrets comes from the templates in env/*.env.example (the "# secret, ..." line above each name).
# It prints NAMES ONLY, never a value, a length or a hash: the same name with the same value is listed as SHARED.
# A secret missing on one side is listed as MISSING. Exit 0 when nothing is shared, 1 otherwise. Read-only.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 2

ROOT="${ILTIAM_ROOT:-/srv/iltiam}"
STAGING_DIR="$ROOT/env/staging"
PROD_DIR="$ROOT/env/production"
[ -d "$STAGING_DIR" ] || { echo "no $STAGING_DIR" >&2; exit 2; }
[ -d "$PROD_DIR" ] || { echo "no $PROD_DIR: production is not set up yet (#36)" >&2; exit 2; }

# The secret names of one template: the NAME= line right after a "# secret" comment.
secret_names() {
  awk '/^# secret/ { s = 1; next } s && /^[A-Z][A-Z0-9_]*=/ { sub(/=.*/, ""); print; s = 0; next } !/^#/ { s = 0 }' "$1"
}

# The value of NAME in an env file, without quotes around it. Never printed.
value_of() {
  [ -f "$2" ] || return 0
  sed -n "s/^$1=//p" "$2" 2>/dev/null | tr -d '\r' | tail -n 1 | sed -e "s/^'\\(.*\\)'\$/\\1/" -e 's/^"\(.*\)"$/\1/'
}

shared=0 missing=0 checked=0 side=""
for template in env/*.env.example; do
  file="$(basename "$template" .example)"
  for name in $(secret_names "$template"); do
    staging="$(value_of "$name" "$STAGING_DIR/$file")"
    prod="$(value_of "$name" "$PROD_DIR/$file")"
    checked=$((checked + 1))
    if [ -z "$staging" ] || [ -z "$prod" ]; then
      # Some secrets are optional on one side (staging-only test passwords, prod-only keys).
      if [ -n "$staging" ] || [ -n "$prod" ]; then
        side=production; [ -n "$staging" ] || side=staging
        echo "  MISSING  $file $name ($side has none)"
        missing=$((missing + 1))
      fi
      continue
    fi
    if [ "$staging" = "$prod" ]; then
      echo "  SHARED   $file $name"
      shared=$((shared + 1))
    fi
  done
done
unset staging prod

echo "Checked $checked secret names: $shared shared, $missing missing on one side."
if [ "$shared" -gt 0 ]; then
  echo "Rotate each SHARED one in production (docs/secrets.md, section 6), deploy, run this again."
  exit 1
fi
echo "No secret is shared between staging and production."
