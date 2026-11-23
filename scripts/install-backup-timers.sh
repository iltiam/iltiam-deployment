#!/usr/bin/env bash
# Install the nightly backup and the weekly restore test of one or both environments on iltiam-1 (Runbook 6,
# section 6; issue #8). Run once per environment, as ubuntu, from the VM's clone:
#
#   sudo bash /srv/iltiam/repo/scripts/install-backup-timers.sh staging
#   sudo bash /srv/iltiam/repo/scripts/install-backup-timers.sh production      (when production runs, #36)
#   sudo bash /srv/iltiam/repo/scripts/install-backup-timers.sh --remove <env>  (stops and removes that env's timers)
#
# Safe to re-run: it writes only what differs. It installs:
#   - the packages age and rclone (Ubuntu 24.04);
#   - /srv/iltiam/backups/tmp (700) and /srv/iltiam/backups/status (755), owned by deploy;
#   - iltiam-backup@.service and iltiam-restore-test@.service, run as deploy, from /srv/iltiam/repo/scripts;
#   - per environment, two timers (Asia/Riyadh, the VM's time zone; a run missed while the VM was off starts at boot):
#       staging      backup 02:30 every day   restore test Fridays 04:00
#       production   backup 02:15 every day   restore test Fridays 04:30
# The units hold no secret: the scripts read /srv/iltiam/env/<env>/backup.env, which the deploy writes.

set -euo pipefail

ROOT=/srv/iltiam
REPO="$ROOT/repo"
DEPLOY_USER=deploy
UNIT_DIR=/etc/systemd/system

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
ok() { printf '    ok: %s\n' "$*"; }

remove=false
if [[ "${1:-}" == --remove ]]; then
  remove=true
  shift
fi
[[ $# -eq 1 && ("$1" == staging || "$1" == production) ]] \
  || die "usage: sudo bash $0 [--remove] <staging|production>"
env_name="$1"
case "$env_name" in
  staging) backup_at='*-*-* 02:30:00' restore_at='Fri *-*-* 04:00:00' ;;
  production) backup_at='*-*-* 02:15:00' restore_at='Fri *-*-* 04:30:00' ;;
esac

[[ "$EUID" -eq 0 ]] || die "run as root: sudo bash $0 $*"

if [[ "$remove" == true ]]; then
  for unit in "iltiam-backup-$env_name.timer" "iltiam-restore-test-$env_name.timer"; do
    systemctl disable --now "$unit" >/dev/null 2>&1 || true
    rm -f "$UNIT_DIR/$unit"
    ok "removed $unit"
  done
  systemctl daemon-reload
  exit 0
fi

mountpoint -q "$ROOT" || die "$ROOT is not mounted (Runbook 1, section 10)"
[[ -d "$REPO/.git" ]] || die "$REPO is not a clone of this repository (Runbook 5, section 4.3)"
[[ -f "$REPO/scripts/backup.sh" ]] \
  || die "$REPO has no scripts/backup.sh yet: deploy a commit that has it first (Runbook 6, section 2)"
id "$DEPLOY_USER" >/dev/null 2>&1 || die "user $DEPLOY_USER not found (Runbook 1)"
[[ "$(timedatectl show -p Timezone --value)" == Asia/Riyadh ]] || die "the VM's time zone must be Asia/Riyadh (Runbook 1)"

echo "==> packages"
missing=()
for pkg in age rclone; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' || missing+=("$pkg")
done
if ((${#missing[@]})); then
  DEBIAN_FRONTEND=noninteractive apt-get -y -q update >/dev/null
  DEBIAN_FRONTEND=noninteractive apt-get -y -q install "${missing[@]}" >/dev/null
  ok "installed ${missing[*]}"
else
  ok "age and rclone already installed"
fi
printf '    age %s, %s\n' "$(age --version)" "$(rclone version | head -n 1)"

echo "==> folders"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$ROOT/backups" "$ROOT/backups/tmp"
install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$ROOT/backups/status"
# backups/ itself is 700, so the status files are readable only through a bind mount (Runbook 7 mounts the folder).
ok "$ROOT/backups (700), tmp (700), status (755), owned by $DEPLOY_USER"

# Write $2 to unit file $1 only if it differs. Returns 0 when it changed.
write_unit() {
  local path="$UNIT_DIR/$1" content="$2"
  if [[ -f "$path" && "$(cat "$path")" == "$content" ]]; then return 1; fi
  printf '%s\n' "$content" >"$path"
  chmod 644 "$path"
  ok "wrote $1"
}

echo "==> systemd units"
changed=false
service() {
  local kind="$1" script="$2" what="$3"
  cat <<EOF
# Written by scripts/install-backup-timers.sh (Runbook 6, issue #8). Holds no secret.
[Unit]
Description=ILTIAM $what (%i)
Documentation=https://github.com/iltiam/iltiam-deployment/blob/main/docs/runbooks/06-backups.md
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target
RequiresMountsFor=$ROOT

[Service]
Type=oneshot
User=$DEPLOY_USER
Group=$DEPLOY_USER
WorkingDirectory=/tmp
ExecStart=/usr/bin/bash $REPO/scripts/$script %i
Nice=10
IOSchedulingClass=idle
TimeoutStartSec=2h
NoNewPrivileges=true
PrivateTmp=true
SyslogIdentifier=iltiam-$kind
EOF
}
timer() {
  local kind="$1" at="$2" what="$3"
  cat <<EOF
# Written by scripts/install-backup-timers.sh (Runbook 6, issue #8).
[Unit]
Description=ILTIAM $what ($env_name)

[Timer]
OnCalendar=$at
Persistent=true
Unit=iltiam-$kind@$env_name.service

[Install]
WantedBy=timers.target
EOF
}
write_unit iltiam-backup@.service "$(service backup backup.sh 'nightly database backup')" && changed=true
write_unit iltiam-restore-test@.service "$(service restore-test restore-test.sh 'weekly restore test')" && changed=true
write_unit "iltiam-backup-$env_name.timer" "$(timer backup "$backup_at" 'nightly database backup')" && changed=true
write_unit "iltiam-restore-test-$env_name.timer" "$(timer restore-test "$restore_at" 'weekly restore test')" \
  && changed=true
[[ "$changed" == true ]] || ok "units already in place"
systemctl daemon-reload
systemctl enable --now "iltiam-backup-$env_name.timer" "iltiam-restore-test-$env_name.timer" >/dev/null 2>&1
ok "timers enabled"

echo "==> next runs"
systemctl list-timers --no-pager "iltiam-backup-$env_name.timer" "iltiam-restore-test-$env_name.timer"
