#!/usr/bin/env bash
# The nightly database backup of one environment (Runbook 6, issue #8). Runs on iltiam-1 as deploy, from the
# systemd timer scripts/install-backup-timers.sh installs (02:30 staging, 02:15 production, Asia/Riyadh).
#
# Usage, on the VM as deploy:  /srv/iltiam/repo/scripts/backup.sh <staging|production>
#
#   1. Guards: not root, /srv/iltiam mounted, postgres running, backup.env complete, the age key pair matches,
#      at least 1 GB free.
#   2. In a working directory (mode 700) on the data volume:
#        iltiam.dump, iltiam_ai.dump   pg_dump -Fc of both databases, checked with pg_restore --list
#        globals.sql                   roles and settings, without passwords (pg_dumpall --globals-only)
#        counts-<db>.tsv               rows per table, for the restore test to compare
#        manifest.txt, SHA256SUMS      what this is, and each file's checksum
#   3. One tar of those, encrypted with age to BACKUP_AGE_RECIPIENT; the plain files are deleted right away, and the
#      encrypted file is decrypted once to prove the key works.
#   4. Upload to iltiam-<SHORT>-backups: daily/<env>-<UTC time>.tar.age, and on Fridays the same file to weekly/.
#      The bucket's lifecycle rules delete daily/ after 14 days and weekly/ after 56 (Runbook 6, section 3); the
#      backup user can't delete or overwrite anything.
#   5. backups/status/<env>-nightly.prom for Runbook 7 (#10), and a ping to BACKUP_PING_URL: start, then success or
#      fail. A missing success ping is the "missing nightly backup" alert.
#
# Nothing stays on the VM: the working directory is removed on any exit. The dumps never leave OCI Riyadh
# (docs/privacy/restore-location.md). Prints names, sizes and counts only, never a value or a row.

# env_name, short, project and bucket are set by backup_env_name (scripts/lib/backup-common.sh).
# shellcheck disable=SC2154
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/backup-common.sh
. "$here/lib/backup-common.sh"

[[ $# -eq 1 ]] || die "usage: $0 <staging|production>"
backup_env_name "$1"
repo="$(cd "$here/.." && pwd)"
compose() { bash "$repo/scripts/compose.sh" "$env_name" "$@"; }
pg() { compose exec -T postgres "$@"; }

echo "==> nightly backup ($env_name)"
[[ "$(id -u)" -ne 0 ]] || die "run as deploy, not root"
[[ "$ILTIAM_ROOT" != /srv/iltiam ]] || mountpoint -q "$ILTIAM_ROOT" \
  || die "$ILTIAM_ROOT is not mounted: the data volume is missing (Runbook 5, section 13)"
for tool in age age-keygen rclone sha256sum tar; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found: run scripts/install-backup-timers.sh (Runbook 6, section 6)"
done

backup_load_env "$ILTIAM_ROOT/env/$env_name/backup.env"
backup_require BACKUP_STORAGE_ACCESS_KEY BACKUP_STORAGE_SECRET_KEY STORAGE_ENDPOINT_URL STORAGE_REGION \
  BACKUP_AGE_RECIPIENT BACKUP_AGE_IDENTITY

ok=0
work=""
finish() {
  local rc=$?
  [[ -z "$work" ]] || rm -rf -- "$work"
  if ((ok)); then
    backup_status nightly 1 "${size:-}"
    backup_ping "${BACKUP_PING_URL:-}" success
  else
    backup_status nightly 0
    backup_ping "${BACKUP_PING_URL:-}" fail
    printf 'FAILED: nightly backup of %s (exit %s); nothing was uploaded unless a line above says so\n' \
      "$env_name" "$rc" >&2
  fi
}
trap finish EXIT
backup_ping "${BACKUP_PING_URL:-}" start

# Only one backup of an environment at a time.
exec 9>"$BACKUP_DIR/.nightly-$env_name.lock"
flock -n 9 || die "another backup of $env_name is running"

# A backup the private key can't open is worthless: check the pair before dumping anything.
[[ "$(age-keygen -y <(printf '%s\n' "$BACKUP_AGE_IDENTITY") 2>/dev/null)" == "$BACKUP_AGE_RECIPIENT" ]] \
  || die "BACKUP_AGE_RECIPIENT is not the public key of BACKUP_AGE_IDENTITY (Runbook 6, section 8)"
[[ -n "$(compose ps -q --status running postgres)" ]] || die "postgres is not running in $env_name"
backup_check_space

umask 077
work="$(backup_workdir nightly)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
name="$env_name-$stamp.tar.age"

echo "==> dump"
mkdir "$work/plain"
for db in iltiam iltiam_ai; do
  # </dev/null: `compose exec` forwards stdin into the container (see scripts/pre-deploy-backup.sh).
  pg pg_dump --username postgres --no-password --format custom --dbname "$db" </dev/null >"$work/plain/$db.dump" \
    || die "pg_dump of $db failed"
  # pg_restore reads the archive's table of contents: a truncated or broken dump fails here.
  pg pg_restore --list <"$work/plain/$db.dump" >/dev/null || die "the dump of $db can't be read back"
  pg psql --username postgres --no-password --dbname "$db" -At -F $'\t' -v ON_ERROR_STOP=1 -c "$BACKUP_COUNT_SQL" \
    </dev/null >"$work/plain/counts-$db.tsv" || die "counting the rows of $db failed"
  say "$db: $(du -h "$work/plain/$db.dump" | cut -f1), $(wc -l <"$work/plain/counts-$db.tsv" | tr -d ' ') tables, $(awk -F'\t' '{s += $2} END {print s + 0}' "$work/plain/counts-$db.tsv") rows"
done
pg pg_dumpall --username postgres --no-password --globals-only --no-role-passwords </dev/null >"$work/plain/globals.sql" \
  || die "pg_dumpall --globals-only failed"
{
  printf 'format=iltiam-backup-1\n'
  printf 'env=%s\n' "$env_name"
  printf 'created_utc=%s\n' "$stamp"
  printf 'server_version=%s\n' "$(pg psql --username postgres --no-password -At -c 'SHOW server_version' </dev/null | tr -d '\r')"
  # The image tags this environment ran: the schema belongs to the backend tag.
  grep -E '^[A-Z_]+_IMAGE=' "$repo/env/$env_name.versions" | tr -d '\r'
} >"$work/plain/manifest.txt"
(cd "$work/plain" && sha256sum iltiam.dump iltiam_ai.dump globals.sql counts-iltiam.tsv counts-iltiam_ai.tsv \
  manifest.txt >SHA256SUMS)

echo "==> encrypt"
tar -cf - -C "$work/plain" . | age --encrypt --recipient "$BACKUP_AGE_RECIPIENT" --output "$work/$name" \
  || die "age failed"
rm -rf -- "$work/plain"
# The listing first, then the match: `grep -q` would stop reading early, and tar's SIGPIPE fail the pipeline.
listing="$(age --decrypt --identity <(printf '%s\n' "$BACKUP_AGE_IDENTITY") "$work/$name" | tar -tf -)" \
  || die "the encrypted file does not decrypt with BACKUP_AGE_IDENTITY"
grep -qx './SHA256SUMS' <<<"$listing" || die "the encrypted file decrypts, but holds no SHA256SUMS"
size="$(stat -c '%s' "$work/$name")"
say "$name ($(du -h "$work/$name" | cut -f1)), decrypts"

echo "==> upload to $bucket"
backup_rclone_env
prefixes=(daily)
# Friday, in the VM's time zone (Asia/Riyadh).
[[ "$(date +%u)" == 5 ]] && prefixes+=(weekly)
for prefix in "${prefixes[@]}"; do
  rclone copyto --no-traverse --retries 3 --low-level-retries 5 --stats 0 \
    "$work/$name" "bk:$bucket/$prefix/$name" || die "the upload to $prefix/ failed"
  remote_size="$(rclone lsf --files-only --format s "bk:$bucket/$prefix/$name")" || die "can't read back $prefix/$name"
  [[ "$remote_size" == "$size" ]] || die "$prefix/$name has $remote_size bytes in the bucket, $size here"
  say "$prefix/$name: $size bytes"
done

ok=1
echo "Backup: $env_name done ($name)."
