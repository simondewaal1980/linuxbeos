#!/usr/bin/env bash
# Bouwt de LinuxBeOS-ISO.
#
# Standaard gebeurt dat in de geïsoleerde Debian Sid build-VM: de projectmap
# wordt via rsync gekopieerd, de ISO wordt daar gebouwd en daarna opgehaald
# naar dist/. Met --local wordt de build op de huidige (Debian Sid-)machine
# uitgevoerd.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

MODE=remote
SKIP_HOST_CHECK=0
NO_SYNC=0
KEEP_WORKDIR=0
TIMEOUT=1800

usage() {
  cat <<EOF
Gebruik: $0 [opties]

Bouwt dist/$ISO_NAME in de Debian Sid build-VM.

Opties:
  --local            Bouw op deze machine (moet Debian Sid met live-build zijn)
  --no-sync          Synchroniseer de projectmap niet opnieuw naar de VM
  --keep-workdir     Hergebruik de buildmap in de VM (sneller, minder schoon)
  --skip-host-check  Sla scripts/00-check-host.sh over
  --timeout N        Timeout voor SSH/cloud-init (standaard 1800)
  -h, --help         Deze uitleg
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --local) MODE=local ;;
    --no-sync) NO_SYNC=1 ;;
    --keep-workdir) KEEP_WORKDIR=1 ;;
    --skip-host-check) SKIP_HOST_CHECK=1 ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout vereist een waarde"
      TIMEOUT="$2"; shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done

mkdir -p "$DIST_DIR" "$BUILD_DIR"

if (( ! SKIP_HOST_CHECK )); then
  step "Host controleren"
  "$SCRIPT_DIR/00-check-host.sh"
fi

if [[ "$MODE" == "local" ]]; then
  step "Lokale build op $(hostname)"
  [[ -f /etc/debian_version ]] || warn "dit lijkt geen Debian-systeem; de build kan mislukken"
  BUILD_ARGS=()
  (( KEEP_WORKDIR )) && BUILD_ARGS+=(--keep-workdir)
  # 11-build-iso-in-vm.sh regelt zelf sudo en de standaard bouwmap.
  BUILD_LOG="$BUILD_DIR/lb-build.out"
  set +e
  "$SCRIPT_DIR/11-build-iso-in-vm.sh" "${BUILD_ARGS[@]}" 2>&1 | tee "$BUILD_LOG"
  status=${PIPESTATUS[0]}
  set -e
  (( status == 0 )) || die "lokale build mislukt; zie $BUILD_LOG"
  SOURCE_ISO="$(awk -F= '$1=="LINUXBEOS_ISO" {print $2}' "$BUILD_LOG" | tail -1)"
  SOURCE_SHA="$(awk -F= '$1=="LINUXBEOS_SHA256" {print $2}' "$BUILD_LOG" | tail -1)"
  SOURCE_INFO="$(dirname "$SOURCE_ISO")/build-info.txt"
else
  step "Build-VM controleren"
  if ! vm_is_running; then
    log "build-VM draait niet; aanmaken/starten ..."
    "$SCRIPT_DIR/01-create-build-vm.sh" --timeout "$TIMEOUT"
  elif ! vm_ssh_ready; then
    if ! wait_for_vm_ssh "$TIMEOUT"; then
      die "build-VM draait maar SSH is niet bereikbaar; zie $VM_SERIAL_LOG"
    fi
  fi
  if ! wait_for_cloud_init "$TIMEOUT"; then
    die "cloud-init in de build-VM is niet klaar"
  fi
  ok "build-VM is klaar"

  step "Project synchroniseren naar build-VM"
  vm_ssh "mkdir -p '$BUILD_VM_SRC_DIR'"
  if (( NO_SYNC )); then
    log "--no-sync: bestaande bronmap in de VM wordt gebruikt"
  else
    vm_rsync \
      --exclude='.git/' \
      --exclude='.build/' \
      --exclude='dist/' \
      --exclude='tests/vm/' \
      --exclude='*.qcow2' \
      --exclude='*.iso' \
      "$PROJECT_ROOT/" \
      "$BUILD_VM_SSH_USER@127.0.0.1:$BUILD_VM_SRC_DIR/"
    ok "broncode gesynchroniseerd"
  fi

  step "ISO bouwen in de build-VM"
  BUILD_LOG="$BUILD_DIR/lb-build.out"
  REMOTE_CMD="sudo env LINUXBEOS_WORKDIR='$BUILD_VM_WORKDIR' bash '$BUILD_VM_SRC_DIR/scripts/11-build-iso-in-vm.sh'"
  if (( KEEP_WORKDIR )); then
    REMOTE_CMD+=" --keep-workdir"
  fi
  set +e
  vm_ssh "$REMOTE_CMD" 2>&1 | tee "$BUILD_LOG"
  status=${PIPESTATUS[0]}
  set -e
  (( status == 0 )) || die "build in de VM mislukt; zie $BUILD_LOG"

  SOURCE_ISO="$(awk -F= '$1=="LINUXBEOS_ISO" {print $2}' "$BUILD_LOG" | tail -1)"
  SOURCE_SHA="$(awk -F= '$1=="LINUXBEOS_SHA256" {print $2}' "$BUILD_LOG" | tail -1)"
  [[ -n "$SOURCE_ISO" ]] || die "kon het ISO-pad niet uit de builduitvoer halen"
  SOURCE_INFO="$(dirname "$SOURCE_ISO")/build-info.txt"
fi

[[ -n "${SOURCE_SHA:-}" ]] || die "kon de SHA256 niet uit de builduitvoer halen"

step "ISO publiceren"
TARGET_ISO="$DIST_DIR/$ISO_NAME"
rm -f "$TARGET_ISO" "$DIST_DIR/SHA256SUMS" "$DIST_DIR/build-info.txt"

if [[ "$MODE" == "local" ]]; then
  cp "$SOURCE_ISO" "$TARGET_ISO"
  [[ -f "$SOURCE_INFO" ]] && cp "$SOURCE_INFO" "$DIST_DIR/build-info.txt"
else
  vm_fetch "$SOURCE_ISO" "$TARGET_ISO"
  vm_fetch "$SOURCE_INFO" "$DIST_DIR/build-info.txt" 2>/dev/null || true
fi

ACTUAL_SHA="$(sha256_of "$TARGET_ISO")"
if [[ "$ACTUAL_SHA" != "$SOURCE_SHA" ]]; then
  rm -f "$TARGET_ISO"
  die "SHA256 komt niet overeen na ophalen (verwacht $SOURCE_SHA, kreeg $ACTUAL_SHA)"
fi

if [[ -f "$DIST_DIR/build-info.txt" ]]; then
  {
    printf 'iso-naam:      %s\n' "$ISO_NAME"
    printf 'sha256:        %s\n' "$ACTUAL_SHA"
    printf 'bron:          %s\n' "$MODE"
  } >> "$DIST_DIR/build-info.txt"
fi

(
  cd "$DIST_DIR"
  sha256sum "$ISO_NAME" > SHA256SUMS
)

step "Klaar"
ok "ISO:     $TARGET_ISO"
ok "grootte: $(du -h "$TARGET_ISO" | awk '{print $1}')"
ok "sha256:  $ACTUAL_SHA"
ok "buildlog: $BUILD_LOG"
