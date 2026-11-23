#!/usr/bin/env bash
# The weekly restore test of one environment (Runbook 6, issue #8). Runs on iltiam-1 as deploy, from the systemd
# timer scripts/install-backup-timers.sh installs (Fridays, 04:00 staging, 04:30 production, Asia/Riyadh), and by
# hand for the go-live check.
#
# Usage, on the VM as deploy:  /srv/iltiam/repo/scripts/restore-test.sh <staging|production>
#
#   1. The newest daily/ backup in iltiam-<SHORT>-backups; it must be at most 26 hours old.
#   2. Download it into a working directory (mode 700), decrypt it with BACKUP_AGE_IDENTITY, check SHA256SUMS.
#   3. A throwaway Postgres container (the image compose.yml runs, 384 MB, no published port) on the environment's
#      internal network, which has no route out of the VM. Both databases restored into it with --exit-on-error.
#   4. Every table of the backup is there, and no table that had rows is empty (compared with counts-<db>.tsv).
#   5. With the backend profile on: `manage.py check --database default` in the running backend image, against the
#      restored database. Read-only, like every command here.
#   6. The container and the working directory are removed on any exit. backups/status/<env>-restore-test.prom for
#      Runbook 7 (#10), and a ping to BACKUP_RESTORE_PING_URL.
#
# The live databases are never touched. Prints names, counts and times only, never a value or a row.

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
container="$project-restore-test"

echo "==> restore test ($env_name)"
[[ "$(id -u)" -ne 0 ]] || die "run as deploy, not root"
[[ "$ILTIAM_ROOT" != /srv/iltiam ]] || mountpoint -q "$ILTIAM_ROOT" \
  || die "$ILTIAM_ROOT is not mounted: the data volume is missing (Runbook 5, section 13)"
for tool in age rclone sha256sum tar openssl; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool not found: run scripts/install-backup-timers.sh (Runbook 6, section 6)"
done

backup_load_env "$ILTIAM_ROOT/env/$env_name/backup.env"
backup_require BACKUP_STORAGE_ACCESS_KEY BACKUP_STORAGE_SECRET_KEY STORAGE_ENDPOINT_URL STORAGE_REGION \
  BACKUP_AGE_IDENTITY

ok=0
work=""
finish() {
  local rc=$?
  docker rm -f -v "$container" >/dev/null 2>&1 || true
  [[ -z "$work" ]] || rm -rf -- "$work"
  if ((ok)); then
    backup_status restore-test 1
    backup_ping "${BACKUP_RESTORE_PING_URL:-}" success
  else
    backup_status restore-test 0
    backup_ping "${BACKUP_RESTORE_PING_URL:-}" fail
    printf 'FAILED: restore test of %s (exit %s)\n' "$env_name" "$rc" >&2
  fi
}
trap finish EXIT
backup_ping "${BACKUP_RESTORE_PING_URL:-}" start

exec 9>"$BACKUP_DIR/.restore-test-$env_name.lock"
flock -n 9 || die "another restore test of $env_name is running"
backup_check_space
network="${project}_internal"
docker network inspect "$network" >/dev/null 2>&1 || die "network $network not found: is $env_name deployed?"
image="$(sed -n 's/^    image: \(postgres:[^[:space:]]*\)$/\1/p' "$repo/compose.yml" | head -n 1)"
[[ -n "$image" ]] || die "can't find the postgres image in compose.yml"
# A leftover from a test that was killed.
docker rm -f -v "$container" >/dev/null 2>&1 || true

echo "==> the newest backup"
backup_rclone_env
re="$(backup_name_re "$env_name")"
name="$(rclone lsf --files-only "bk:$bucket/daily/" | grep -E "$re" | sort | tail -n 1 || true)"
[[ -n "$name" ]] || die "no backup of $env_name in $bucket/daily/"
taken="$(backup_name_epoch "$name")" || die "can't read the time in $name"
age_h=$((($(date +%s) - taken) / 3600))
((age_h <= BACKUP_MAX_AGE_H)) || die "the newest backup, $name, is $age_h hours old (more than $BACKUP_MAX_AGE_H)"
say "$name, $age_h hours old"

umask 077
work="$(backup_workdir restore)"
rclone copyto --retries 3 --stats 0 "bk:$bucket/daily/$name" "$work/$name" || die "the download failed"
mkdir "$work/plain"
age --decrypt --identity <(printf '%s\n' "$BACKUP_AGE_IDENTITY") "$work/$name" | tar -xf - -C "$work/plain" \
  || die "decrypting or unpacking $name failed"
rm -f -- "${work:?}/$name"
(cd "$work/plain" && sha256sum --quiet --check SHA256SUMS) || die "a file of $name does not match SHA256SUMS"
grep -qx "env=$env_name" "$work/plain/manifest.txt" || die "$name is not a backup of $env_name"
say "decrypted, checksums match ($(sed -n 's/^server_version=//p' "$work/plain/manifest.txt" | cut -d' ' -f1))"

echo "==> restore into a throwaway database"
RESTORE_PG_PASSWORD="$(openssl rand -hex 24)"
export RESTORE_PG_PASSWORD
# The password reaches the container from this environment (-e NAME alone), never from a command line.
POSTGRES_PASSWORD="$RESTORE_PG_PASSWORD" docker run -d --name "$container" --network "$network" \
  --memory 384m --security-opt no-new-privileges:true --log-driver json-file --log-opt max-size=10m \
  -e POSTGRES_PASSWORD "$image" postgres -c shared_buffers=64MB -c max_connections=10 >/dev/null \
  || die "the throwaway Postgres did not start"
for _ in $(seq 1 60); do
  docker exec "$container" pg_isready -h 127.0.0.1 -U postgres -q 2>/dev/null && break
  sleep 2
done
docker exec "$container" pg_isready -h 127.0.0.1 -U postgres -q || die "the throwaway Postgres is not ready after 2 minutes"
psql_in() { docker exec -i "$container" psql --username postgres --no-password -v ON_ERROR_STOP=1 "$@"; }

for db in iltiam iltiam_ai; do
  psql_in -q -c "CREATE DATABASE $db" </dev/null >/dev/null || die "creating $db failed"
  start="$(date +%s)"
  # --no-owner --no-acl: the roles of the live database don't exist here, and aren't needed to read the data.
  docker exec -i "$container" pg_restore --username postgres --no-password --dbname "$db" --no-owner --no-acl \
    --exit-on-error <"$work/plain/$db.dump" || die "pg_restore of $db failed"
  psql_in --dbname "$db" -At -F $'\t' -c "$BACKUP_COUNT_SQL" </dev/null >"$work/restored-$db.tsv" \
    || die "counting the rows of the restored $db failed"
  # Every table of the backup is there; a table that had rows still has rows. The counts were taken a moment after
  # the dump, so a busy table may differ by a few rows: that is not a failure.
  problems="$(awk -F'\t' 'NR == FNR { got[$1] = $2; next }
    !($1 in got) { print "missing table " $1; next }
    $2 + 0 > 0 && got[$1] + 0 == 0 { print "empty table " $1 " (had " $2 " rows)" }' \
    "$work/restored-$db.tsv" "$work/plain/counts-$db.tsv")"
  [[ -z "$problems" ]] || die "$db restored wrongly: $(tr '\n' ';' <<<"$problems")"
  say "$db: $(wc -l <"$work/restored-$db.tsv" | tr -d ' ') tables, $(awk -F'\t' '{s += $2} END {print s + 0}' "$work/restored-$db.tsv") rows, restored in $(($(date +%s) - start)) s"
done

profiles="$(sed -n 's/^COMPOSE_PROFILES=//p' "$repo/env/$env_name.versions" | tr -d '\r' | tail -n 1)"
if [[ ",$profiles," == *",backend,"* ]]; then
  echo "==> manage.py check against the restored database"
  # A one-off backend container (the running tag), on the internal network, pointed at the throwaway database.
  # `check` only reads. DATABASE_URL reaches it from this environment (-e NAME alone), never from a command line.
  DATABASE_URL="postgres://postgres:$RESTORE_PG_PASSWORD@$container:5432/iltiam" \
    compose run --rm --no-deps -T -e DATABASE_URL backend-migrate python manage.py check --database default \
    </dev/null >"$work/check.log" 2>&1 || {
    tail -n 20 "$work/check.log" >&2
    die "manage.py check failed against the restored database"
  }
  say "$(tail -n 1 "$work/check.log")"
else
  say "the backend profile is off in $env_name: no manage.py check"
fi

ok=1
echo "Restore test: $env_name passed ($name)."
