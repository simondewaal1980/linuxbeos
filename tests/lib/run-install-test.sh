#!/usr/bin/env bash
# Geautomatiseerde acceptatietest voor de Calamares-installatie.
#
# Fase 1:
#   1. start de live-ISO in een lege qcow2-VM met het SMBIOS-kenmerk
#      LINUXBEOS-AUTOINSTALL;
#   2. de live-sessie start Calamares automatisch, doorloopt de standaard
#      moduleketen en schrijft LINUXBEOS_AUTOINSTALL done naar de seriële
#      console;
#   3. de VM start opnieuw, nu zonder ISO, van de geïnstalleerde schijf;
#   4. de test wacht op LINUXBEOS_INSTALLED_READY en de Xfce-sessiemarkering.
#
# Alleen qcow2-schijven onder tests/vm/ worden gebruikt.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
. "$SCRIPT_DIR/../../scripts/lib/common.sh"

MODE="${1:-}"
[[ "$MODE" == "uefi" || "$MODE" == "bios" ]] || die "gebruik: $0 <uefi|bios> [opties]"
shift

ISO="$DIST_DIR/$ISO_NAME"
INSTALL_TIMEOUT=1800
BOOT_TIMEOUT=1800
MEMORY=4096
CPUS=4
KEEP=0

usage() {
  cat <<EOF
Gebruik: $0 <uefi|bios> [opties]

Test een volledige Calamares-installatie op een lege qcow2-schijf en de
daaropvolgende zelfstandige boot van het geïnstalleerde systeem.

  --iso PATH           Te testen ISO (standaard: dist/$ISO_NAME)
  --install-timeout N  Timeout voor de installatiefase (standaard 1800 s)
  --boot-timeout N     Timeout voor de boot/rollback-test van het doel systeem (standaard 1800 s)
  --memory MB          Geheugen voor de test-VM (standaard 4096)
  --cpus N             vCPU's voor de test-VM (standaard 4)
  --keep               Bewaar de testmap (schijf, OVMF-vars, logs, screenshot)
  -h, --help           Deze uitleg
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --iso)
      [[ $# -ge 2 ]] || die "--iso vereist een pad"
      ISO="$2"; shift
      ;;
    --install-timeout)
      [[ $# -ge 2 ]] || die "--install-timeout vereist een waarde"
      INSTALL_TIMEOUT="$2"; shift
      ;;
    --boot-timeout)
      [[ $# -ge 2 ]] || die "--boot-timeout vereist een waarde"
      BOOT_TIMEOUT="$2"; shift
      ;;
    --memory)
      [[ $# -ge 2 ]] || die "--memory vereist een waarde"
      MEMORY="$2"; shift
      ;;
    --cpus)
      [[ $# -ge 2 ]] || die "--cpus vereist een waarde"
      CPUS="$2"; shift
      ;;
    --keep) KEEP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done

require_cmd qemu-system-x86_64 qemu-img grep awk
[[ -f "$ISO" ]] || die "ISO niet gevonden: $ISO (bouw eerst met scripts/10-build-iso.sh)"
[[ -n "$QEMU_BIN" ]] || die "qemu-system-x86_64 niet gevonden"

WORK="$TEST_VM_DIR/install-$MODE"
DISK="$WORK/disk.qcow2"
OVMF_VARS="$WORK/OVMF_VARS.fd"
MONITOR="$WORK/monitor.sock"
INSTALL_SERIAL="$WORK/install-serial.log"
BOOT_SERIAL="$WORK/boot-serial.log"
INSTALL_RESULT="$WORK/install-result.txt"
BOOT_RESULT="$WORK/boot-result.txt"
SCREENSHOT="$WORK/installed-system.png"

# Elke testrun begint met een lege schijf en verse OVMF-variabelen; --keep
# bewaart de artefacten na de run, maar hergebruikt ze niet als startpunt.
rm -rf "$WORK"
mkdir -p "$WORK"
rm -f "$OVMF_VARS" "$MONITOR" "$INSTALL_SERIAL" "$BOOT_SERIAL" "$INSTALL_RESULT" "$BOOT_RESULT"

QEMU_PID=""
cleanup() {
  if [[ -n "$QEMU_PID" ]] && kill -0 "$QEMU_PID" 2>/dev/null; then
    kill "$QEMU_PID" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
      kill -0 "$QEMU_PID" 2>/dev/null || break
      sleep 1
    done
    kill -9 "$QEMU_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if kvm_available; then
  ACCEL=kvm
  CPU=host
else
  ACCEL=tcg
  CPU=max
  warn "KVM niet beschikbaar; de test valt terug op TCG en kan zeer traag zijn"
fi

"$QEMU_IMG" create -q -f qcow2 "$DISK" 20G

# Firmware- en schijfargumenten. Dezelfde OVMF-variabelen worden voor de
# installatie en de daaropvolgende boot gebruikt, zodat de EFI-bootentry
# bewaard blijft.
firmware_args() {
  if [[ "$MODE" == "uefi" ]]; then
    local code
    code="$(ovmf_code_path)" || die "OVMF_CODE niet gevonden"
    if [[ ! -f "$OVMF_VARS" ]]; then
      cp "$(ovmf_vars_path)" "$OVMF_VARS"
    fi
    printf '%s\0' \
      -machine q35,accel="$ACCEL" \
      -drive "if=pflash,format=raw,readonly=on,file=$code" \
      -drive "if=pflash,format=raw,file=$OVMF_VARS"
  else
    printf '%s\0' -machine pc,accel="$ACCEL"
  fi
}

common_args() {
  printf '%s\0' \
    -cpu "$CPU" \
    -smp "$CPUS" \
    -m "$MEMORY" \
    -rtc base=utc \
    -drive "file=$DISK,if=virtio,format=qcow2" \
    -netdev "user,id=net0" \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    -smbios "type=1,serial=LINUXBEOS-AUTOINSTALL" \
    -display none
}

readarray -d '' FIRMWARE_ARGS < <(firmware_args)
readarray -d '' COMMON_ARGS < <(common_args)

start_qemu() {
  local serial="$1"
  shift
  "$QEMU_BIN" \
    "${FIRMWARE_ARGS[@]}" \
    "${COMMON_ARGS[@]}" \
    -serial "file:$serial" \
    -monitor "unix:$MONITOR,server,nowait" \
    "$@" &
  QEMU_PID=$!
}

screenshot() {
  local target="$1"
  have_cmd socat || { warn "socat ontbreekt; geen screenshot"; return 0; }
  # Even wachten zodat de desktop, het paneel en de achtergrond gerenderd zijn.
  sleep 5
  local ppm="$WORK/screenshot.ppm"
  rm -f "$ppm"
  if printf 'screendump %s\n' "$ppm" \
      | timeout 10 socat - "UNIX-CONNECT:$MONITOR" >/dev/null 2>&1 && [[ -s "$ppm" ]]; then
    if have_cmd convert && convert "$ppm" "$target" 2>/dev/null; then
      :
    elif have_cmd pnmtopng && pnmtopng "$ppm" > "$target" 2>/dev/null; then
      :
    else
      mv "$ppm" "$target"
    fi
    ok "screenshot: $target"
  else
    warn "kon geen screenshot via de QEMU-monitor maken"
  fi
}

wait_for_marker() {
  local file="$1" pattern="$2" timeout="$3" process="$4"
  local start=$SECONDS
  while (( SECONDS - start < timeout )); do
    if grep -aq "$pattern" "$file" 2>/dev/null; then
      return 0
    fi
    if ! kill -0 "$process" 2>/dev/null; then
      # QEMU is gestopt; één laatste controle na het laatste schrijfwerk.
      sleep 1
      grep -aq "$pattern" "$file" 2>/dev/null && return 0
      return 2
    fi
    sleep 2
  done
  return 1
}

wait_for_qemu_exit() {
  local timeout="$1" start=$SECONDS
  while kill -0 "$QEMU_PID" 2>/dev/null; do
    (( SECONDS - start >= timeout )) && return 1
    sleep 1
  done
  return 0
}

step "Installatie ($MODE)"
log "ISO:      $ISO"
log "testmap:  $WORK"
log "accel:    $ACCEL"
start_qemu "$INSTALL_SERIAL" \
  -drive "file=$ISO,media=cdrom,readonly=on,format=raw" \
  -boot "order=d,menu=on"

# Eerst controleren dat de live-sessie de autoinstall-hulp daadwerkelijk
# heeft gestart. Zonder deze markering heeft wachten op "done" geen zin.
set +e
wait_for_marker "$INSTALL_SERIAL" "LINUXBEOS_AUTOINSTALL start" 300 "$QEMU_PID"
started_status=$?
set -e
if (( started_status != 0 )); then
  screenshot "$WORK/install-failed.png" || true
  warn "de autoinstall-hulp is niet gestart; laatste 60 regels:"
  tail -n 60 "$INSTALL_SERIAL" >&2 || true
  die "autoinstall startte niet in de live-sessie ($MODE)"
fi

set +e
wait_for_marker "$INSTALL_SERIAL" "LINUXBEOS_AUTOINSTALL done" "$INSTALL_TIMEOUT" "$QEMU_PID"
install_status=$?
set -e

if (( install_status != 0 )); then
  screenshot "$WORK/install-failed.png" || true
  {
    printf 'mode=%s\n' "$MODE"
    printf 'resultaat=mislukt\n'
    printf 'fase=installatie\n'
    printf 'status=%s\n' "$install_status"
  } > "$INSTALL_RESULT"
  if grep -aq 'LINUXBEOS_AUTOINSTALL failed' "$INSTALL_SERIAL" 2>/dev/null; then
    warn "autoinstall-melding: $(grep -a 'LINUXBEOS_AUTOINSTALL failed' "$INSTALL_SERIAL" | tail -1)"
  fi
  warn "laatste 80 regels uit het installatielog:"
  tail -n 80 "$INSTALL_SERIAL" >&2 || true
  die "installatie ($MODE) mislukt; volledig log: $INSTALL_SERIAL"
fi

ok "installatie voltooid"
{
  printf 'mode=%s\n' "$MODE"
  printf 'resultaat=geslaagd\n'
  printf 'marker=%s\n' "$(grep -a 'LINUXBEOS_AUTOINSTALL done' "$INSTALL_SERIAL" | tail -1)"
} > "$INSTALL_RESULT"

if ! wait_for_qemu_exit 60; then
  warn "QEMU stopte niet na de installatie; wordt geforceerd beëindigd"
  kill "$QEMU_PID" 2>/dev/null || true
fi
QEMU_PID=""

step "Geïnstalleerd systeem starten ($MODE)"
rm -f "$MONITOR"
start_qemu "$BOOT_SERIAL" -boot "order=c,menu=on"

# De Btrfs-test doorloopt drie boots: snapshot maken, vanaf de snapshot
# booten en daarna de rollback verifiëren. QEMU blijft tijdens die
# herstarts draaien, dus alle markeringen komen in hetzelfde log terecht.
step "Btrfs-snapshot en rollback testen ($MODE)"
set +e
wait_for_marker "$BOOT_SERIAL" "LINUXBEOS_BTRFS_TEST done" "$BOOT_TIMEOUT" "$QEMU_PID"
btrfs_status=$?
set -e

if (( btrfs_status != 0 )); then
  screenshot "$WORK/boot-failed.png" || true
  {
    printf 'mode=%s\n' "$MODE"
    printf 'resultaat=mislukt\n'
    printf 'fase=btrfs-rollback\n'
    printf 'status=%s\n' "$btrfs_status"
  } > "$BOOT_RESULT"
  if grep -aq 'LINUXBEOS_BTRFS_TEST skipped' "$BOOT_SERIAL" 2>/dev/null; then
    warn "Btrfs-test overgeslagen: $(grep -a 'LINUXBEOS_BTRFS_TEST skipped' "$BOOT_SERIAL" | tail -1)"
  fi
  if grep -aq 'LINUXBEOS_BTRFS_TEST failed' "$BOOT_SERIAL" 2>/dev/null; then
    warn "Btrfs-test mislukt: $(grep -a 'LINUXBEOS_BTRFS_TEST failed' "$BOOT_SERIAL" | tail -1)"
  fi
  warn "laatste 120 regels uit het bootlog:"
  tail -n 120 "$BOOT_SERIAL" >&2 || true
  die "Btrfs/snapshot/rollback-test ($MODE) mislukt; volledig log: $BOOT_SERIAL"
fi

# Op de laatste boot moeten ook de gewone installed-ready- en Xfce-markers
# aanwezig zijn. De Btrfs-hulp wacht zelf op de Xfce-sessie voordat hij
# "done" schrijft; deze controles zijn de expliciete bevestiging.
set +e
wait_for_marker "$BOOT_SERIAL" "LINUXBEOS_INSTALLED_READY" 180 "$QEMU_PID"
boot_status=$?
set -e
if (( boot_status != 0 )); then
  screenshot "$WORK/boot-failed.png" || true
  warn "laatste 80 regels uit het bootlog:"
  tail -n 80 "$BOOT_SERIAL" >&2 || true
  die "geïnstalleerd systeem ($MODE) meldt zich niet als gereed; volledig log: $BOOT_SERIAL"
fi

if ! grep -aq 'LINUXBEOS_SMOKE session=xfce' "$BOOT_SERIAL" 2>/dev/null; then
  screenshot "$WORK/boot-failed.png" || true
  die "Xfce-sessie in het geïnstalleerde systeem ($MODE) niet bevestigd"
fi

# Fase 3: het thema moet via unpackfs ook op het doelsysteem actief zijn.
THEME_MARKER="$(grep -a 'LINUXBEOS_THEME ok' "$BOOT_SERIAL" 2>/dev/null | tail -1 || true)"
if [[ -z "$THEME_MARKER" ]]; then
  warn "geen LINUXBEOS_THEME-marker in het geïnstalleerde systeem ($MODE)"
else
  ok "thema: $THEME_MARKER"
fi

screenshot "$SCREENSHOT" || true

{
  printf 'mode=%s\n' "$MODE"
  printf 'resultaat=geslaagd\n'
  printf 'installed-ready=%s\n' "$(grep -a 'LINUXBEOS_INSTALLED_READY' "$BOOT_SERIAL" | tail -1)"
  printf 'smoke=%s\n' "$(grep -a 'LINUXBEOS_SMOKE' "$BOOT_SERIAL" | tail -1)"
  printf 'theme=%s\n' "${THEME_MARKER:-niet gemeld}"
  printf 'btrfs-layout=%s\n' "$(grep -a 'LINUXBEOS_BTRFS_LAYOUT' "$BOOT_SERIAL" | tail -1)"
  printf 'snapshot=%s\n' "$(grep -a 'LINUXBEOS_BTRFS_SNAPSHOT ok' "$BOOT_SERIAL" | tail -1)"
  printf 'grub=%s\n' "$(grep -a 'LINUXBEOS_BTRFS_GRUB' "$BOOT_SERIAL" | tail -1)"
  printf 'snapshot-boot=%s\n' "$(grep -a 'LINUXBEOS_BTRFS_SNAPSHOT_BOOT' "$BOOT_SERIAL" | tail -1)"
  printf 'rollback=%s\n' "$(grep -a 'LINUXBEOS_BTRFS_ROLLBACK ok' "$BOOT_SERIAL" | tail -1)"
} > "$BOOT_RESULT"

ok "geïnstalleerd systeem start zelfstandig"
ok "marker: $(grep -a 'LINUXBEOS_SMOKE' "$BOOT_SERIAL" | tail -1)"
ok "btrfs:  $(grep -a 'LINUXBEOS_BTRFS_ROLLBACK ok' "$BOOT_SERIAL" | tail -1)"
ok "log:    $BOOT_SERIAL"
(( KEEP )) && ok "testmap bewaard: $WORK"
