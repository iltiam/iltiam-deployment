# shellcheck shell=bash
# shellcheck disable=SC2034  # the settings below are read by the scripts that source this file
# Shared by scripts/backup.sh and scripts/restore-test.sh (Runbook 6, issue #8). Sourced, never run.
#
# Prints names, sizes, counts and times only, never a value of backup.env, the bucket's endpoint or a ping URL.
# ILTIAM_ROOT (default /srv/iltiam) lets scripts/check-env.sh test these functions against a temporary directory.

ILTIAM_ROOT="${ILTIAM_ROOT:-/srv/iltiam}"
BACKUP_DIR="$ILTIAM_ROOT/backups"
# Free space both scripts need on the data volume, which the database shares.
BACKUP_MIN_FREE_MB=1024
# A nightly backup older than this fails the restore test, and Runbook 7 (#10) alerts on it.
BACKUP_MAX_AGE_H=26
# The names backup.env may hold (env/backup.env.example). Anything else in the file is refused.
BACKUP_ENV_NAMES=(BACKUP_STORAGE_ACCESS_KEY BACKUP_STORAGE_SECRET_KEY STORAGE_ENDPOINT_URL STORAGE_REGION
  BACKUP_AGE_RECIPIENT BACKUP_AGE_IDENTITY BACKUP_PING_URL BACKUP_RESTORE_PING_URL)

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
say() { printf '    %s\n' "$*"; }

# Sets env_name, short (staging|prod), project (the Compose project) and bucket from the first argument.
backup_env_name() {
  case "${1:-}" in
    staging) short=staging project=iltiam-staging ;;
    production) short=prod project=iltiam-prod ;;
    *) die "environment must be staging or production, got '${1:-}'" ;;
  esac
  env_name="$1"
  bucket="iltiam-$short-backups"
}

# The object names this environment writes: <env>-<UTC time>.tar.age, under daily/ (and weekly/ on Fridays).
backup_name_re() { printf '^%s-[0-9]{8}T[0-9]{6}Z\\.tar\\.age$' "$1"; }

# The UTC time in an object name, in seconds since 1970.
backup_name_epoch() {
  local stamp="${1%.tar.age}"
  stamp="${stamp##*-}"
  [[ "$stamp" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})T([0-9]{2})([0-9]{2})([0-9]{2})Z$ ]] || return 1
  date -u -d "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}" +%s
}

# Read backup.env into shell variables without running it. render-env.sh writes NAME='value' lines; only the names
# above are taken, and any other line (except blank lines and comments) is refused.
backup_load_env() {
  local file="$1" line name value known n
  [[ -r "$file" ]] || die "$file not found or not readable: deploy $env_name first (Runbook 6, section 8)"
  # On the VM only: Git Bash on Windows (scripts/check-env.sh) can't show a mode of 600.
  [[ "$ILTIAM_ROOT" != /srv/iltiam || "$(stat -c '%a' "$file")" == 600 ]] || die "$file must have mode 600"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == '#'* ]] && continue
    [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=\'([^\']*)\'$ ]] || die "$file: a line that is not NAME='value'"
    name="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    known=false
    for n in "${BACKUP_ENV_NAMES[@]}"; do [[ "$n" == "$name" ]] && known=true; done
    [[ "$known" == true ]] || die "$file: $name is not a backup setting"
    printf -v "$name" '%s' "$value"
  done <"$file"
}

# Refuse to go on unless each named setting is set (names only in the message).
backup_require() {
  local name missing=()
  for name in "$@"; do [[ -n "${!name:-}" ]] || missing+=("$name"); done
  ((${#missing[@]} == 0)) \
    || die "missing from backup.env: ${missing[*]} (set them in the GitHub Environment and deploy, Runbook 6, section 8)"
}

# rclone reads its remote "bk" from these variables: no config file, nothing on a command line.
backup_rclone_env() {
  export RCLONE_CONFIG_BK_TYPE=s3 RCLONE_CONFIG_BK_PROVIDER=Other RCLONE_CONFIG_BK_FORCE_PATH_STYLE=true
  export RCLONE_CONFIG_BK_NO_CHECK_BUCKET=true RCLONE_CONFIG_BK_ENV_AUTH=false
  export RCLONE_CONFIG_BK_ACCESS_KEY_ID="$BACKUP_STORAGE_ACCESS_KEY"
  export RCLONE_CONFIG_BK_SECRET_ACCESS_KEY="$BACKUP_STORAGE_SECRET_KEY"
  export RCLONE_CONFIG_BK_ENDPOINT="$STORAGE_ENDPOINT_URL"
  export RCLONE_CONFIG_BK_REGION="$STORAGE_REGION"
  # rclone must never read or write a config file of its own.
  export RCLONE_CONFIG=/dev/null
}

# The free dead-man check (Runbook 6, section 5): start, success or fail. Never fails the job, never prints the URL.
backup_ping() {
  local url="$1" what="$2" suffix=""
  [[ -n "$url" ]] || return 0
  case "$what" in
    start) suffix=/start ;;
    fail) suffix=/fail ;;
  esac
  curl -fsS -m 10 --retry 3 -o /dev/null "$url$suffix" 2>/dev/null || say "note: the $what ping did not go through"
}

# A Prometheus text file for Runbook 7's node-exporter (#10): written whole, then renamed.
#   backup_status <kind> <1|0> [size in bytes]
backup_status() {
  local kind="$1" ok="$2" size="${3:-}" dir="$BACKUP_DIR/status" file tmp now
  [[ -d "$dir" ]] || return 0
  file="$dir/$env_name-$kind.prom"
  tmp="$dir/.$env_name-$kind.prom.tmp"
  now="$(date +%s)"
  {
    printf '# HELP iltiam_backup_last_run_timestamp_seconds When this job last ended.\n'
    printf '# TYPE iltiam_backup_last_run_timestamp_seconds gauge\n'
    printf 'iltiam_backup_last_run_timestamp_seconds{env="%s",job="%s"} %s\n' "$env_name" "$kind" "$now"
    printf '# HELP iltiam_backup_last_run_success 1 if this job last ended well.\n'
    printf '# TYPE iltiam_backup_last_run_success gauge\n'
    printf 'iltiam_backup_last_run_success{env="%s",job="%s"} %s\n' "$env_name" "$kind" "$ok"
    if [[ "$ok" == 1 ]]; then
      printf '# HELP iltiam_backup_last_success_timestamp_seconds When this job last ended well.\n'
      printf '# TYPE iltiam_backup_last_success_timestamp_seconds gauge\n'
      printf 'iltiam_backup_last_success_timestamp_seconds{env="%s",job="%s"} %s\n' "$env_name" "$kind" "$now"
    elif [[ -f "$file" ]]; then
      # Keep the last success's time across a failure.
      grep '^iltiam_backup_last_success_timestamp_seconds' "$file" || true
    fi
    if [[ -n "$size" ]]; then
      printf '# HELP iltiam_backup_last_size_bytes Size of the last uploaded backup.\n'
      printf '# TYPE iltiam_backup_last_size_bytes gauge\n'
      printf 'iltiam_backup_last_size_bytes{env="%s"} %s\n' "$env_name" "$size"
    fi
  } >"$tmp"
  chmod 644 "$tmp"
  mv -f "$tmp" "$file"
}

# A working directory under backups/tmp (mode 700), removed by the caller's trap.
backup_workdir() {
  local base="$BACKUP_DIR/tmp"
  [[ -d "$base" ]] || die "$base is missing: run scripts/install-backup-timers.sh (Runbook 6, section 6)"
  [[ "$(stat -c '%U' "$base")" == "$(id -un)" ]] || die "$base must be owned by $(id -un)"
  mktemp -d "$base/$1-XXXXXX"
}

# Stop unless the data volume has room for the dumps.
backup_check_space() {
  local free_mb
  free_mb="$(df -Pm "$BACKUP_DIR" | awk 'NR == 2 {print $4}')"
  [[ "$free_mb" =~ ^[0-9]+$ ]] || die "can't read the free space of $BACKUP_DIR"
  ((free_mb >= BACKUP_MIN_FREE_MB)) \
    || die "only $free_mb MB free on $ILTIAM_ROOT; need $BACKUP_MIN_FREE_MB MB (the database shares this volume)"
}

# One line per table of the public schema: "<table>\t<rows>". Table names and numbers only, never a row.
# shellcheck disable=SC2016  # $$ and %I are SQL, not shell
BACKUP_COUNT_SQL="SELECT c.relname, (xpath('/row/n/text()', query_to_xml(format('SELECT count(*) AS n FROM %I.%I', n.nspname, c.relname), false, true, '')))[1]::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind = 'r' AND n.nspname = 'public' ORDER BY 1"
