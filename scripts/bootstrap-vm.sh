#!/usr/bin/env bash
# Bootstrap the ILTIAM VM (Ubuntu 24.04 LTS, aarch64) after first login.
# Runbook: docs/runbooks/01-oci-account-and-vm.md
#
# Usage:  sudo bash bootstrap-vm.sh
#
# Safe to re-run: every step checks the current state first and only changes
# what is missing. It never reboots; it tells you when a reboot is required.

set -euo pipefail

VM_HOSTNAME="iltiam-1"
TIMEZONE="Asia/Riyadh"
DEPLOY_USER="deploy"
ADMIN_USER="ubuntu"
SWAP_FILE="/swapfile"
SWAP_SIZE="4G"
SSHD_DROPIN="/etc/ssh/sshd_config.d/01-iltiam.conf"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a   # no interactive "restart services?" prompt on 24.04

log() { printf '\n==> %s\n' "$*"; }
ok() { printf '    ok: %s\n' "$*"; }

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# Write $2 to file $1 only if the content differs. Returns 0 if it changed.
write_if_changed() {
  local path="$1" content="$2"
  if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$content" ]]; then
    return 1
  fi
  printf '%s\n' "$content" >"$path"
  return 0
}

pkg_installed() {
  # shellcheck disable=SC2016  # ${Status} is a dpkg-query field, not a shell variable
  [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]]
}

apt_get() {
  apt-get -y -q \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    "$@"
}

# --- 0. Guards ---------------------------------------------------------------

[[ "${EUID}" -eq 0 ]] || die "run as root: sudo bash $0"
[[ "$(uname -m)" == "aarch64" ]] || die "expected aarch64, got $(uname -m)"
# shellcheck source=/dev/null
. /etc/os-release
[[ "${ID}" == "ubuntu" ]] || die "expected Ubuntu, got ${ID}"
if [[ "${VERSION_ID}" != "24.04" ]]; then
  printf 'WARNING: written for Ubuntu 24.04, this is %s\n' "${VERSION_ID}" >&2
fi

# --- 1. Packages -------------------------------------------------------------

log "apt update and upgrade"
apt_get update
apt_get upgrade
apt_get install ca-certificates curl unattended-upgrades fail2ban python3-systemd

# --- 2. Hostname -------------------------------------------------------------

log "hostname ${VM_HOSTNAME}"
if [[ "$(hostnamectl --static)" != "${VM_HOSTNAME}" ]]; then
  hostnamectl set-hostname "${VM_HOSTNAME}"
  ok "hostname set"
else
  ok "already ${VM_HOSTNAME}"
fi
# Stop cloud-init from putting the VNIC hostname back on reboot, and from
# rewriting /etc/hosts with it.
if [[ -d /etc/cloud/cloud.cfg.d ]]; then
  if write_if_changed /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg \
    "$(printf '%s\n' '# Written by scripts/bootstrap-vm.sh' \
      'preserve_hostname: true' 'manage_etc_hosts: false')"; then
    ok "cloud-init told to preserve the hostname"
  fi
fi
# sudo resolves the hostname; the VCN resolver only knows the VNIC name.
if ! grep -Eq "^[^#]*[[:space:]]${VM_HOSTNAME}([[:space:]]|$)" /etc/hosts; then
  printf '127.0.1.1 %s\n' "${VM_HOSTNAME}" >>/etc/hosts
  ok "added ${VM_HOSTNAME} to /etc/hosts"
fi

# --- 3. Timezone -------------------------------------------------------------

log "timezone ${TIMEZONE}"
if [[ "$(timedatectl show -p Timezone --value)" != "${TIMEZONE}" ]]; then
  timedatectl set-timezone "${TIMEZONE}"
  ok "timezone set"
else
  ok "already ${TIMEZONE}"
fi

# --- 4. Docker Engine + compose plugin (docs.docker.com apt repository) -------

log "Docker Engine and compose plugin"
if grep -rqs 'download.docker.com' /etc/apt/sources.list /etc/apt/sources.list.d/; then
  ok "Docker apt repository already configured (left as is)"
else
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    if pkg_installed "$pkg"; then
      apt_get remove "$pkg"
    fi
  done
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt_get update
  ok "Docker apt repository added"
fi
docker_pkgs=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
missing=()
for pkg in "${docker_pkgs[@]}"; do
  pkg_installed "$pkg" || missing+=("$pkg")
done
if ((${#missing[@]})); then
  apt_get install "${missing[@]}"
  ok "installed ${missing[*]}"
else
  ok "Docker packages already installed"
fi
systemctl enable --now docker.service containerd.service >/dev/null

# --- 5. Users ----------------------------------------------------------------

log "users and the docker group"
if ! id "${DEPLOY_USER}" >/dev/null 2>&1; then
  # No password is set, so the account can only be reached with an SSH key.
  useradd --create-home --shell /bin/bash "${DEPLOY_USER}"
  ok "created ${DEPLOY_USER} (no password)"
fi
for user in "${ADMIN_USER}" "${DEPLOY_USER}"; do
  if [[ " $(id -nG "$user") " == *" docker "* ]]; then
    ok "${user} already in docker"
  else
    usermod -aG docker "$user"
    ok "${user} added to docker (takes effect at next login)"
  fi
done

# --- 6. unattended-upgrades --------------------------------------------------

log "unattended-upgrades"
write_if_changed /etc/apt/apt.conf.d/20auto-upgrades \
  "$(printf '%s\n' 'APT::Periodic::Update-Package-Lists "1";' \
    'APT::Periodic::Unattended-Upgrade "1";')" || true
systemctl enable --now unattended-upgrades.service >/dev/null
ok "enabled (security updates daily, no automatic reboot)"

# --- 7. SSH: key-only login --------------------------------------------------

log "sshd: key-only login"
# 01- sorts before 50-cloudimg-settings.conf; sshd keeps the first value it reads.
sshd_conf="$(printf '%s\n' '# Written by scripts/bootstrap-vm.sh' \
  'PasswordAuthentication no' \
  'KbdInteractiveAuthentication no' \
  'PermitRootLogin no')"
if write_if_changed "${SSHD_DROPIN}" "${sshd_conf}"; then
  install -d -m 0755 /run/sshd   # sshd -t needs it; absent while ssh.socket is idle
  if ! sshd -t; then
    rm -f "${SSHD_DROPIN}"
    die "sshd -t failed; removed ${SSHD_DROPIN}, SSH config unchanged"
  fi
  systemctl try-reload-or-restart ssh.service
  ok "drop-in written and sshd reloaded; test a NEW login before closing this one"
else
  ok "drop-in already in place"
fi

# --- 8. fail2ban -------------------------------------------------------------

log "fail2ban"
if write_if_changed /etc/fail2ban/jail.d/iltiam.local \
  "$(printf '%s\n' '# Written by scripts/bootstrap-vm.sh' '[sshd]' \
    'enabled = true' 'backend = systemd')"; then
  systemctl enable fail2ban.service >/dev/null
  systemctl restart fail2ban.service
  ok "sshd jail enabled"
else
  systemctl enable --now fail2ban.service >/dev/null
  ok "already configured"
fi

# --- 9. rpcbind --------------------------------------------------------------

log "rpcbind off (it listens on 0.0.0.0:111; nothing here uses NFS)"
if systemctl cat rpcbind.service >/dev/null 2>&1; then
  rpcbind_on=false
  for unit in rpcbind.socket rpcbind.service; do
    if systemctl is-active --quiet "$unit" \
      || [[ "$(systemctl is-enabled "$unit" 2>/dev/null)" == "enabled" ]]; then
      rpcbind_on=true
    fi
  done
  if [[ "${rpcbind_on}" == true ]]; then
    # Socket first, or systemd warns that the service's triggering unit is still active.
    systemctl disable --now --quiet rpcbind.socket
    systemctl disable --now --quiet rpcbind.service
    ok "rpcbind stopped and disabled"
  else
    ok "rpcbind already disabled"
  fi
else
  ok "rpcbind not installed"
fi

# --- 10. Swap ----------------------------------------------------------------

log "swap ${SWAP_SIZE}"
if [[ -n "$(swapon --show --noheadings)" ]]; then
  ok "swap already active"
else
  if [[ ! -f "${SWAP_FILE}" ]]; then
    fallocate -l "${SWAP_SIZE}" "${SWAP_FILE}"
    chmod 600 "${SWAP_FILE}"
    mkswap "${SWAP_FILE}" >/dev/null
  fi
  swapon "${SWAP_FILE}"
  ok "${SWAP_FILE} active"
fi
if [[ -f "${SWAP_FILE}" ]] && ! grep -Eq "^${SWAP_FILE}[[:space:]]" /etc/fstab; then
  printf '%s none swap sw 0 0\n' "${SWAP_FILE}" >>/etc/fstab
  ok "${SWAP_FILE} added to /etc/fstab"
fi

# --- 11. Summary -------------------------------------------------------------

log "summary"
printf 'hostname:  %s\n' "$(hostnamectl --static)"
printf 'arch:      %s\n' "$(uname -m)"
printf 'cpus:      %s\n' "$(nproc)"
printf 'timezone:  %s\n' "$(timedatectl show -p Timezone --value)"
echo
free -h
echo
swapon --show
echo
df -h /
echo
docker --version
docker compose version

if [[ -f /var/run/reboot-required ]]; then
  echo
  echo "REBOOT REQUIRED. Packages asking for it:"
  sed 's/^/    /' /var/run/reboot-required.pkgs 2>/dev/null || true
  echo "Run: sudo reboot   (then log in again)"
else
  echo
  echo "No reboot required. Log out and back in so the docker group applies."
fi
