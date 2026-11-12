#!/usr/bin/env bash
# A copy of the staging backend database, taken before an automatic backend deploy (Runbook 9, section 6; issue #16).
#
# Usage, from the deploy workflow only: scripts/remote-deploy.sh --backup staging backend-sha-<7>
# remote-deploy.sh copies this file to a temporary file on iltiam-1 and runs it there as deploy, BEFORE the commit and
# before the VM's clone moves: so it dumps the database the running backend uses, and it does not depend on which
# commit the VM has checked out.
#
#   1. Guards: not root, /srv/iltiam mounted, postgres running, at least MIN_FREE_MB free on the volume.
#   2. pg_dump of database iltiam (the backend's; the AI service's iltiam_ai is not part of a backend deploy), as the
#      postgres superuser over the container's local socket, gzipped into a hidden temporary file.
#   3. Check the file (gzip test, pg_dump's closing line), make it 600 and give it its name:
#        /srv/iltiam/backups/pre-deploy/<UTC time>-backend-sha-<7>.sql.gz   (the folder: 700, deploy)
#   4. Keep the newest KEEP files, delete the older ones.
#
# Any failure exits non-zero and leaves no partial file, and the workflow then stops before it changes anything.
# Prints the file name and size, never its content: the workflow's log is public. The last line is
# BACKUP_FILE=<name> for the workflow's summary. Restoring: Runbook 9, section 7.

set -euo pipefail

ROOT=/srv/iltiam
DIR="$ROOT/backups/pre-deploy"
KEEP=5
MIN_FREE_MB=1024

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || die "usage: $0 staging backend-sha-<7>"
env_name="$1"
label="$2"
[[ "$env_name" == staging ]] || die "pre-deploy backups are for staging only, got '$env_name'"
[[ "$label" =~ ^backend-sha-[0-9a-f]{7}$ ]] || die "the label must be backend-sha-<7>"

compose() { bash "$ROOT/repo/scripts/compose.sh" "$env_name" "$@"; }

echo "==> pre-deploy backup ($env_name, $label)"
[[ "$(id -u)" -ne 0 ]] || die "run as deploy, not root"
mountpoint -q "$ROOT" || die "$ROOT is not mounted: the data volume is missing (Runbook 5, section 13)"
[[ -n "$(compose ps -q --status running postgres)" ]] || die "postgres is not running in $env_name"

if [[ ! -d "$DIR" ]]; then
  (umask 077 && mkdir -p "$DIR") 2>/dev/null \
    || die "$DIR is missing and deploy can't create it: create it once (Runbook 9, section 2)"
fi
[[ "$(stat -c '%U' "$DIR")" == "$(id -un)" ]] || die "$DIR must be owned by $(id -un) (Runbook 9, section 2)"
chmod 700 "$DIR"

free_mb="$(df -Pm "$DIR" | awk 'NR == 2 {print $4}')"
[[ "$free_mb" =~ ^[0-9]+$ ]] || die "can't read the free space of $DIR"
((free_mb >= MIN_FREE_MB)) || die "only $free_mb MB free on $ROOT; need $MIN_FREE_MB MB (the database shares this volume)"

name="$(date -u +%Y%m%dT%H%M%SZ)-$label.sql.gz"
umask 077
tmp="$DIR/.$name.tmp"
trap 'rm -f "$tmp"' EXIT

# </dev/null: `compose exec` forwards its stdin into the container. Without it, a caller's stdin would go to pg_dump
# (#16: run over SSH, that was the rest of this script).
compose exec -T postgres pg_dump --username postgres --no-password --dbname iltiam </dev/null | gzip -c >"$tmp" \
  || die "pg_dump failed; nothing was deployed"
gzip -t "$tmp" || die "the dump is not a valid gzip file"
# Near the end, not the last line: pg_dump 16.10 and newer write a `\unrestrict` line after it.
gzip -dc "$tmp" | tail -n 12 | grep -q '^-- PostgreSQL database dump complete' \
  || die "the dump is incomplete (pg_dump's closing line is missing)"
chmod 600 "$tmp"
mv -f "$tmp" "$DIR/$name"
trap - EXIT
printf '    ok: %s (%s)\n' "$name" "$(du -h "$DIR/$name" | cut -f1)"

# The newest first by name: every name starts with its UTC time.
mapfile -t all < <(find "$DIR" -maxdepth 1 -type f -name '*.sql.gz' -printf '%f\n' | sort -r)
for old in "${all[@]:KEEP}"; do
  rm -f -- "${DIR:?}/$old"
  printf '    deleted the older %s\n' "$old"
done
printf '    kept: %s of at most %s\n' "$(find "$DIR" -maxdepth 1 -type f -name '*.sql.gz' | wc -l)" "$KEEP"

echo "BACKUP_FILE=$name"
