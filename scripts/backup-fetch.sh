#!/usr/bin/env bash
# Fetch one backup for a real restore (docs/runbooks/06-restore.md, issue #8): download it from the environment's
# -backups bucket, decrypt it, check SHA256SUMS, and leave the plain files in a folder (mode 700) on the data volume.
#
# Usage, on the VM as deploy:
#   /srv/iltiam/repo/scripts/backup-fetch.sh <staging|production> --list         the backups in daily/ and weekly/
#   /srv/iltiam/repo/scripts/backup-fetch.sh <staging|production> [<name>]       the newest daily/ one, or <name>
#
# The last line is FETCHED=<folder>. The folder holds iltiam.dump, iltiam_ai.dump, globals.sql, the row counts and
# manifest.txt: a full copy of the environment's data. Delete it as soon as the restore is done
# (06-restore.md says when); it never leaves the VM (docs/privacy/restore-location.md).

# env_name, short, project and bucket are set by backup_env_name (scripts/lib/backup-common.sh).
# shellcheck disable=SC2154
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/backup-common.sh
. "$here/lib/backup-common.sh"

[[ $# -ge 1 && $# -le 2 ]] || die "usage: $0 <staging|production> [--list | <name>]"
backup_env_name "$1"
want="${2:-}"
re="$(backup_name_re "$env_name")"
[[ -z "$want" || "$want" == --list || "$want" =~ $re ]] || die "a backup name looks like $env_name-<UTC time>.tar.age"

[[ "$(id -u)" -ne 0 ]] || die "run as deploy, not root"
for tool in age rclone sha256sum tar; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found: run scripts/install-backup-timers.sh (Runbook 6, section 6)"
done
backup_load_env "$ILTIAM_ROOT/env/$env_name/backup.env"
backup_require BACKUP_STORAGE_ACCESS_KEY BACKUP_STORAGE_SECRET_KEY STORAGE_ENDPOINT_URL STORAGE_REGION \
  BACKUP_AGE_IDENTITY
backup_rclone_env

if [[ "$want" == --list ]]; then
  for prefix in daily weekly; do
    echo "==> $bucket/$prefix/"
    rclone lsf --files-only --format sp "bk:$bucket/$prefix/" | grep -E ";$env_name-" | sort -t';' -k2 \
      | awk -F';' '{printf "    %s  %s bytes\n", $2, $1}' || echo "    (none)"
  done
  exit 0
fi

if [[ -z "$want" ]]; then
  want="$(rclone lsf --files-only "bk:$bucket/daily/" | grep -E "$re" | sort | tail -n 1 || true)"
  [[ -n "$want" ]] || die "no backup of $env_name in $bucket/daily/"
fi
prefix=daily
if [[ "$(rclone lsf --files-only "bk:$bucket/daily/$want" 2>/dev/null || true)" != "$want" ]]; then
  prefix=weekly
  [[ "$(rclone lsf --files-only "bk:$bucket/weekly/$want" 2>/dev/null || true)" == "$want" ]] \
    || die "$want is in neither daily/ nor weekly/ (list them: $0 $env_name --list)"
fi
backup_check_space

echo "==> fetch $prefix/$want"
umask 077
dir="$(backup_workdir fetch)"
trap 'rm -rf -- "$dir"' EXIT
rclone copyto --retries 3 --stats 0 "bk:$bucket/$prefix/$want" "$dir/$want" || die "the download failed"
mkdir "$dir/plain"
age --decrypt --identity <(printf '%s\n' "$BACKUP_AGE_IDENTITY") "$dir/$want" | tar -xf - -C "$dir/plain" \
  || die "decrypting or unpacking $want failed"
rm -f -- "${dir:?}/$want"
(cd "$dir/plain" && sha256sum --quiet --check SHA256SUMS) || die "a file of $want does not match SHA256SUMS"
grep -qx "env=$env_name" "$dir/plain/manifest.txt" || die "$want is not a backup of $env_name"
say "decrypted, checksums match; taken $(sed -n 's/^created_utc=//p' "$dir/plain/manifest.txt") (UTC)"
say "backend image then: $(sed -n 's/^BACKEND_IMAGE=.*://p' "$dir/plain/manifest.txt")"
trap - EXIT
echo "FETCHED=$dir/plain"
