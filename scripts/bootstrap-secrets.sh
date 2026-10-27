#!/usr/bin/env bash
# Print fresh random values for ONE GitHub Environment (issue #3).
# Runbook: docs/runbooks/04-secrets.md, section 5.
#
# Usage (Git Bash on Windows, or any Linux or macOS shell):
#   bash scripts/bootstrap-secrets.sh staging
#   bash scripts/bootstrap-secrets.sh production
#
# Needs only openssl, which Git for Windows ships. It does not use Python: in Git Bash on Windows, `python` is
# often the Microsoft Store stub, which fails. It writes nothing to disk and sends nothing anywhere.
#
# Copy each value into Settings > Environments > <env> > Environment secrets, then run `clear` or close the
# terminal. Never save the output to a file, a chat, an issue or a PR. Run it again for the other environment:
# staging and production never share a value.

set -euo pipefail

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 && ("$1" == staging || "$1" == production) ]] || die "usage: bash $0 staging|production"
env_name="$1"
command -v openssl >/dev/null 2>&1 \
  || die "openssl not found. On Windows, run this in Git Bash (Git for Windows includes openssl)."

# Hex is safe everywhere: inside a URL (DATABASE_URL), in Compose files and in shell quotes.
hex() { openssl rand -hex "$1" | tr -d '\r\n'; }
# Fernet wants 32 random bytes in URL-safe base64 with padding: 44 characters ending in "=".
fernet_key() { openssl rand -base64 32 | tr -d '\r\n' | tr '+/' '-_'; }

secret_key="$(hex 32)"
jwt_secret_key="$(hex 32)"
field_encryption_key="$(fernet_key)"
ai_service_token="$(hex 32)"
ai_django_secret_key="$(hex 32)"
postgres_password="$(hex 24)"
backend_db_password="$(hex 24)"
ai_db_password="$(hex 24)"

if [[ ! -t 1 ]]; then
  printf 'WARNING: the output is not going to a terminal. Never save these values to a file.\n' >&2
fi

cat <<EOF
# Fresh values for the GitHub Environment "${env_name}". Never reuse them for the other environment.
# Settings > Environments > ${env_name} > Environment secrets > Add environment secret:
#   Name = the text left of "=", Value = everything right of it.

# backend.env
SECRET_KEY=${secret_key}
JWT_SECRET_KEY=${jwt_secret_key}
# Also save FIELD_ENCRYPTION_KEY in Bitwarden ("ILTIAM escrow"): it can never be rotated or read back from GitHub.
FIELD_ENCRYPTION_KEY=${field_encryption_key}
# backend.env and ai.env (one secret, used by both)
AI_SERVICE_TOKEN=${ai_service_token}

# ai.env
DJANGO_SECRET_KEY=${ai_django_secret_key}

# infra.env
POSTGRES_PASSWORD=${postgres_password}
BACKEND_DB_PASSWORD=${backend_db_password}
AI_DB_PASSWORD=${ai_db_password}

# Done? Run: clear
EOF
