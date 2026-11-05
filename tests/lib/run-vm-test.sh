#!/usr/bin/env bash
# Start de live-ISO in QEMU/KVM en controleert via de seriële console dat de
# Xfce-sessie draait en NetworkManager verbinding heeft.
#
# Wordt aangeroepen door tests/test-uefi.sh en tests/test-bios.sh.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
. "$SCRIPT_DIR/../../scripts/lib/common.sh"

MODE="${1:-}"
[[ "$MODE" == "uefi" || "$MODE" == "bios" ]] || die "gebruik: $0 <uefi|bios> [opties]"
shift

ISO="$DIST_DIR/$ISO_NAME"
GUI=0
KEEP=0
TIMEOUT=300
MEMORY=4096
CPUS=4
THEME_REQUIRED=1
DEMO=1

usage() {
  cat <<EOF
Gebruik: $0 <uefi|bios> [opties]

  --iso PATH       Te testen ISO (standaard: dist/$ISO_NAME)
  --gui            Toon het QEMU-venster; sluit het venster om af te ronden
  --timeout N      Timeout in seconden voor de headless test (standaard 300)
  --memory MB      Geheugen voor de test-VM (standaard 4096)
  --cpus N         vCPU's voor de test-VM (standaard 4)
  --keep           Bewaar de testmap (schijf, OVMF-vars, log)
  --skip-theme     Accepteer een sessie zonder LINUXBEOS_THEME-marker
  --no-demo        Open geen terminal/Thunar voor de vensterscreenshot
  -h, --help       Deze uitleg
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --iso)
      [[ $# -ge 2 ]] || die "--iso vereist een pad"
      ISO="$2"; shift
      ;;
    --gui) GUI=1 ;;
    --keep) KEEP=1 ;;
    --skip-theme) THEME_REQUIRED=0 ;;
    --no-demo) DEMO=0 ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout vereist een waarde"
      TIMEOUT="$2"; shift
      ;;
    --memory)
      [[ $# -ge 2 ]] || die "--memory vereist een waarde"
      MEMORY="$2"; shift
      ;;
    --cpus)
      [[ $# -ge 2 ]] || die "--cpus vereist een waarde"
      CPUS="$2"; shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done

require_cmd qemu-system-x86_64 qemu-img grep awk
[[ -f "$ISO" ]] || die "ISO niet gevonden: $ISO (bouw eerst met scripts/10-build-iso.sh)"
[[ -n "$QEMU_BIN" ]] || die "qemu-system-x86_64 niet gevonden"

WORK="$TEST_VM_DIR/$MODE"
SERIAL="$WORK/serial.log"
RESULT="$WORK/result.txt"
DISK="$WORK/disk.qcow2"
SCREENSHOT="$WORK/screenshot.png"
MONITOR="$WORK/monitor.sock"

rm -rf "$WORK"
mkdir -p "$WORK"

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
  warn "KVM niet beschikbaar; de test valt terug op TCG en kan traag zijn"
fi

"$QEMU_IMG" create -q -f qcow2 "$DISK" 20G

QEMU_ARGS=(
  -name "${DISTRO_SLUG}-test-$MODE"
  -machine "$([[ "$MODE" == "uefi" ]] && echo q35 || echo pc),accel=$ACCEL"
  -cpu "$CPU"
  -smp "$CPUS"
  -m "$MEMORY"
  -rtc base=utc
  -drive "file=$DISK,if=virtio,format=qcow2"
  -drive "file=$ISO,media=cdrom,readonly=on,format=raw"
  -netdev "user,id=net0"
  -device virtio-net-pci,netdev=net0
  -device virtio-rng-pci
  -boot "order=d,menu=on"
  -no-reboot
  -serial "file:$SERIAL"
  -monitor "unix:$MONITOR,server,nowait"
)

if (( DEMO )); then
  QEMU_ARGS+=(-smbios "type=1,serial=LINUXBEOS-THEME-DEMO")
fi

if [[ "$MODE" == "uefi" ]]; then
  OVMF_CODE="$(ovmf_code_path)" || die "OVMF_CODE niet gevonden"
  OVMF_VARS_SRC="$(ovmf_vars_path)" || die "OVMF_VARS niet gevonden"
  cp "$OVMF_VARS_SRC" "$WORK/OVMF_VARS.fd"
  QEMU_ARGS+=(
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
    -drive "if=pflash,format=raw,file=$WORK/OVMF_VARS.fd"
  )
fi

if (( GUI )); then
  [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || die "--gui vereist een grafische sessie (DISPLAY/WAYLAND_DISPLAY)"
  QEMU_ARGS+=(-display gtk)
else
  QEMU_ARGS+=(-display none)
fi

step "LinuxBeOS ISO testen ($MODE)"
log "ISO:    $ISO"
log "testmap: $WORK"
log "accel:  $ACCEL"

"$QEMU_BIN" "${QEMU_ARGS[@]}" &
QEMU_PID=$!

marker_in_log() {
  grep -a 'LINUXBEOS_SMOKE' "$SERIAL" 2>/dev/null | tail -1 || true
}

theme_marker_in_log() {
  grep -a 'LINUXBEOS_THEME' "$SERIAL" 2>/dev/null | tail -1 || true
}

session_and_theme_ready() {
  local marker theme
  marker="$(marker_in_log)"
  theme="$(theme_marker_in_log)"
  [[ "$marker" == *"session=xfce"* && "$marker" == *"network=connected"* ]] || return 1
  if (( THEME_REQUIRED )); then
    [[ "$theme" == *"LINUXBEOS_THEME ok"* ]] || return 1
  fi
  return 0
}

take_screenshot() {
  local target="${1:-$SCREENSHOT}" delay="${2:-5}"
  if (( GUI )); then
    return 0
  fi
  if ! have_cmd socat; then
    warn "socat ontbreekt; geen screenshot gemaakt"
    return 0
  fi
  # Even wachten zodat wallpaper, paneel en desktoppictogrammen gerenderd zijn.
  sleep "$delay"
  local ppm="$WORK/screenshot.ppm"
  rm -f "$ppm"
  if printf 'screendump %s\n' "$ppm" \
      | timeout 10 socat - "UNIX-CONNECT:$MONITOR" >/dev/null 2>&1; then
    if [[ -s "$ppm" ]]; then
      if have_cmd convert && convert "$ppm" "$target" 2>/dev/null; then
        :
      elif have_cmd pnmtopng && pnmtopng "$ppm" > "$target" 2>/dev/null; then
        :
      else
        target="$ppm"
      fi
      if [[ -f "$target" ]]; then
        ok "screenshot: $target"
      fi
      if [[ "$target" != "$ppm" ]]; then
        rm -f "$ppm"
      fi
    else
      warn "screendump leverde geen bestand op"
    fi
  else
    warn "kon geen screenshot via de QEMU-monitor maken"
  fi
}

success=0
marker=""
start=$SECONDS
if (( GUI )); then
  log "QEMU-venster geopend; sluit het venster om de test af te ronden."
  wait "$QEMU_PID" || true
  QEMU_PID=""
  marker="$(marker_in_log)"
  session_and_theme_ready && success=1
else
  while (( SECONDS - start < TIMEOUT )); do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
      warn "QEMU is onverwacht gestopt"
      break
    fi
    marker="$(marker_in_log)"
    if session_and_theme_ready; then
      success=1
      break
    fi
    sleep 2
  done
fi

if (( success )); then
  # Eerst het kale bureaublad (pictogrammen, Deskbar, achtergrond), daarna
  # de testvensters van linuxbeos-theme-demo voor de vensterdecoratie.
  take_screenshot "$WORK/screenshot.png" 8
  take_screenshot "$WORK/screenshot-windows.png" 25
  {
    printf '%s\n' "$marker"
    theme_marker_in_log
  } > "$RESULT"
  ok "XFCE-sessie en netwerk zijn gereed"
  ok "marker: $marker"
  ok "thema:  $(theme_marker_in_log)"
  ok "serieel log: $SERIAL"
  if (( KEEP )); then
    ok "testmap bewaard: $WORK"
  fi
  exit 0
fi

# Bewaar ook bij een mislukte themacontrole een screenshot voor diagnose.
take_screenshot
{
  printf 'mode=%s\n' "$MODE"
  printf 'iso=%s\n' "$ISO"
  printf 'marker=%s\n' "$marker"
  printf 'theme=%s\n' "$(theme_marker_in_log)"
  printf 'resultaat=mislukt\n'
} > "$RESULT"

warn "geen geldige LINUXBEOS_SMOKE-regel met network=connected gevonden"
if [[ -n "$marker" ]]; then
  warn "laatste marker: $marker"
fi
if (( THEME_REQUIRED )); then
  warn "laatste themamarker: $(theme_marker_in_log)"
fi
warn "laatste 60 regels uit het seriële log:"
tail -n 60 "$SERIAL" >&2 || true
die "test ($MODE) mislukt; volledig log: $SERIAL"
