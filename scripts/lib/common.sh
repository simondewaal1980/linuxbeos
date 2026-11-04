#!/usr/bin/env bash
# Gemeenschappelijke helpers voor alle LinuxBeOS-scripts.
#
# Wordt gesourced vanuit een script in scripts/, tests/ of tests/lib/.
# Bepaalt de projectroot op basis van het aanroepende script ($0).

if [[ -z "${BASH_VERSION:-}" ]]; then
  echo "FOUT: dit script vereist bash." >&2
  exit 1
fi

_COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$_COMMON_DIR/../.." && pwd)"

# shellcheck source=../../config/project.conf
. "$PROJECT_ROOT/config/project.conf"

BUILD_DIR="$PROJECT_ROOT/.build"
VM_DIR="$BUILD_DIR/vm"
CACHE_DIR="$BUILD_DIR/cache"
DIST_DIR="$PROJECT_ROOT/dist"
TEST_VM_DIR="$PROJECT_ROOT/tests/vm"

VM_SSH_KEY="$VM_DIR/id_ed25519"
VM_KNOWN_HOSTS="$VM_DIR/known_hosts"
VM_PIDFILE="$VM_DIR/qemu.pid"
VM_SERIAL_LOG="$VM_DIR/serial.log"
VM_BASE_IMAGE="$CACHE_DIR/debian-sid-genericcloud-amd64.qcow2"
VM_OVERLAY="$VM_DIR/disk.qcow2"
VM_SEED_ISO="$VM_DIR/seed.iso"
VM_USER_DATA="$VM_DIR/user-data"
VM_META_DATA="$VM_DIR/meta-data"

# Voorkom dat een qemu-img uit bijvoorbeeld de Android SDK in PATH wordt
# gebruikt; die is niet geschikt voor images van het systeem-QEMU.
if [[ -x /usr/bin/qemu-img ]]; then
  QEMU_IMG=/usr/bin/qemu-img
else
  QEMU_IMG="$(command -v qemu-img || true)"
fi
if [[ -x /usr/bin/qemu-system-x86_64 ]]; then
  QEMU_BIN=/usr/bin/qemu-system-x86_64
else
  QEMU_BIN="$(command -v qemu-system-x86_64 || true)"
fi

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
else
  C_RESET=""
  C_BOLD=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
fi

log()  { printf '%s[%s]%s %s\n' "$C_BLUE" "$(date +%H:%M:%S)" "$C_RESET" "$*"; }
step() { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
ok()   { printf '%s  OK  %s%s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s WAARSCHUWING %s%s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%sFOUT:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
  local cmd
  for cmd in "$@"; do
    have_cmd "$cmd" || die "verplicht commando niet gevonden: $cmd"
  done
}

require_file() {
  [[ -f "$1" ]] || die "verplicht bestand niet gevonden: $1"
}

# Geeft de vrije ruimte in MiB op het bestandssysteem van $1.
free_mib() {
  df -Pm "$1" | awk 'NR==2 {print $4}'
}

kvm_available() {
  [[ -r /dev/kvm && -w /dev/kvm ]]
}

sha256_of() {
  sha256sum "$1" | awk '{print $1}'
}

ovmf_code_path() {
  local p
  for p in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd \
    /usr/share/qemu/OVMF_CODE.fd; do
    [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

ovmf_vars_path() {
  local p
  for p in \
    /usr/share/OVMF/OVMF_VARS_4M.fd \
    /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/edk2/ovmf/OVMF_VARS.fd \
    /usr/share/qemu/OVMF_VARS.fd; do
    [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

# --- Build-VM -------------------------------------------------------------

vm_pid() {
  [[ -f "$VM_PIDFILE" ]] || return 1
  local pid
  pid="$(cat "$VM_PIDFILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  printf '%s\n' "$pid"
}

vm_is_running() {
  local pid
  pid="$(vm_pid)" || return 1
  kill -0 "$pid" 2>/dev/null
}

vm_ssh() {
  ssh -p "$BUILD_VM_SSH_PORT" \
      -i "$VM_SSH_KEY" \
      -o IdentitiesOnly=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile="$VM_KNOWN_HOSTS" \
      -o ConnectTimeout=5 \
      -o BatchMode=yes \
      -o LogLevel=ERROR \
      "$BUILD_VM_SSH_USER@127.0.0.1" "$@"
}

vm_ssh_ready() {
  vm_is_running && vm_ssh true >/dev/null 2>&1
}

vm_rsync() {
  rsync -a --delete \
    -e "ssh -p $BUILD_VM_SSH_PORT -i $VM_SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=$VM_KNOWN_HOSTS -o LogLevel=ERROR" \
    "$@"
}

vm_fetch() {
  local remote_path="$1" local_path="$2"
  rsync -a \
    -e "ssh -p $BUILD_VM_SSH_PORT -i $VM_SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=$VM_KNOWN_HOSTS -o LogLevel=ERROR" \
    "$BUILD_VM_SSH_USER@127.0.0.1:$remote_path" "$local_path"
}

# Wacht tot SSH in de build-VM bereikbaar is. Geeft de laatste seriële
# regels bij een timeout.
wait_for_vm_ssh() {
  local timeout="${1:-900}" waited=0
  while (( waited < timeout )); do
    if vm_ssh_ready; then
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
    if (( waited % 30 == 0 )); then
      log "wachten op SSH in build-VM (${waited}s/${timeout}s) ..."
    fi
  done
  if [[ -f "$VM_SERIAL_LOG" ]]; then
    warn "laatste regels uit $VM_SERIAL_LOG:"
    tail -n 40 "$VM_SERIAL_LOG" >&2 || true
  fi
  return 1
}

# Wacht tot cloud-init (inclusief pakketinstallatie) klaar is.
wait_for_cloud_init() {
  local timeout="${1:-1800}" waited=0
  while (( waited < timeout )); do
    if vm_ssh_ready && vm_ssh 'test -f /home/builder/cloud-init-ready' >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
    if (( waited % 60 == 0 )); then
      log "wachten op cloud-init in build-VM (${waited}s/${timeout}s) ..."
    fi
  done
  warn "cloud-init-status:"
  vm_ssh 'cloud-init status --long' >&2 2>&1 || true
  warn "laatste regels uit /var/log/cloud-init-output.log:"
  vm_ssh 'tail -n 40 /var/log/cloud-init-output.log' >&2 2>&1 || true
  return 1
}

stop_build_vm() {
  local pid
  if ! vm_is_running; then
    rm -f "$VM_PIDFILE"
    return 0
  fi
  pid="$(vm_pid)"
  log "build-VM afsluiten (pid $pid) ..."
  vm_ssh 'sudo poweroff' >/dev/null 2>&1 || true
  local waited=0
  while kill -0 "$pid" 2>/dev/null && (( waited < 60 )); do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    warn "build-VM reageert niet op poweroff; QEMU wordt geforceerd gestopt."
    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$VM_PIDFILE"
}
