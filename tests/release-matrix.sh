#!/usr/bin/env bash
# LinuxBeOS releasematrix.
#
# Dit script is de releasegate: het draait de statische controle, de
# live-rooktesten en de volledige Btrfs-installatietests op UEFI én BIOS en
# controleert de markers die de acceptatiecriteria aantonen. Het resultaat
# wordt als Markdown-rapport vastgelegd in dist/release-matrix.txt.
#
# Gebruik:
#   tests/release-matrix.sh                 volledige matrix
#   tests/release-matrix.sh --skip-install  alleen statisch + rooktesten
#   tests/release-matrix.sh --iso path.iso  een bestaande ISO testen
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/lib/common.sh
. "$SCRIPT_DIR/../scripts/lib/common.sh"

ISO="$DIST_DIR/$ISO_NAME"
RUN_STATIC=1
RUN_SMOKE=1
RUN_INSTALL=1
KEEP=0
REPORT="$DIST_DIR/release-matrix.txt"
SMOKE_TIMEOUT=""
INSTALL_TIMEOUT=""
BOOT_TIMEOUT=""

usage() {
  cat <<EOF
Gebruik: $0 [opties]

Draait de volledige LinuxBeOS-releasematrix:
  statische controle
  UEFI + BIOS live-rooktest (sessie, netwerk, thema)
  UEFI + BIOS Btrfs-installatie (thema op doel, snapshot, snapshot-boot, rollback)

Opties:
  --iso PATH           Te testen ISO (standaard: dist/$ISO_NAME)
  --skip-static        Sla de statische controle over
  --skip-smoke         Sla de live-rooktesten over
  --skip-install       Sla de installatietests over
  --keep               Bewaar de testartefacten
  --smoke-timeout N    Timeout voor de rooktesten
  --install-timeout N  Timeout voor de installatiefase
  --boot-timeout N     Timeout voor de doel-boots (inclusief rollback)
  --report PATH        Rapportpad (standaard: dist/release-matrix.txt)
  -h, --help           Deze uitleg
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --iso)
      [[ $# -ge 2 ]] || die "--iso vereist een pad"
      ISO="$2"; shift
      ;;
    --skip-static) RUN_STATIC=0 ;;
    --skip-smoke) RUN_SMOKE=0 ;;
    --skip-install) RUN_INSTALL=0 ;;
    --keep) KEEP=1 ;;
    --smoke-timeout)
      [[ $# -ge 2 ]] || die "--smoke-timeout vereist een waarde"
      SMOKE_TIMEOUT="$2"; shift
      ;;
    --install-timeout)
      [[ $# -ge 2 ]] || die "--install-timeout vereist een waarde"
      INSTALL_TIMEOUT="$2"; shift
      ;;
    --boot-timeout)
      [[ $# -ge 2 ]] || die "--boot-timeout vereist een waarde"
      BOOT_TIMEOUT="$2"; shift
      ;;
    --report)
      [[ $# -ge 2 ]] || die "--report vereist een pad"
      REPORT="$2"; shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done

require_cmd qemu-system-x86_64 qemu-img grep awk sha256sum
[[ -f "$ISO" ]] || die "ISO niet gevonden: $ISO (bouw eerst met scripts/20-build-release.sh)"

SMOKE_ARGS=(--iso "$ISO")
INSTALL_ARGS=(--iso "$ISO")
if (( KEEP )); then
  SMOKE_ARGS+=(--keep)
  INSTALL_ARGS+=(--keep)
fi
if [[ -n "$SMOKE_TIMEOUT" ]]; then
  SMOKE_ARGS+=(--timeout "$SMOKE_TIMEOUT")
fi
if [[ -n "$INSTALL_TIMEOUT" ]]; then
  INSTALL_ARGS+=(--install-timeout "$INSTALL_TIMEOUT")
fi
if [[ -n "$BOOT_TIMEOUT" ]]; then
  INSTALL_ARGS+=(--boot-timeout "$BOOT_TIMEOUT")
fi

ROWS=()
FAILURES=0
SKIPS=0

add_row() {
  local name="$1" status="$2" evidence="${3:--}"
  evidence="${evidence//|/\/}"
  evidence="${evidence//$'\r'/}"
  ROWS+=("$name|$status|$evidence")
  case "$status" in
    PASS) printf '%s  PASS %s%s  %s\n' "$C_GREEN" "$C_RESET" "$name" "$evidence" ;;
    FAIL) printf '%s  FAIL %s%s  %s\n' "$C_RED" "$C_RESET" "$name" "$evidence"; FAILURES=$((FAILURES + 1)) ;;
    SKIP) printf '%s  SKIP %s%s\n' "$C_YELLOW" "$C_RESET" "$name"; SKIPS=$((SKIPS + 1)) ;;
  esac
}

run_step() {
  local name="$1"
  shift
  step "$name"
  local status=0
  "$@" || status=$?
  if (( status == 0 )); then
    add_row "$name" PASS "exit 0"
  else
    add_row "$name" FAIL "exit $status"
  fi
}

# Laatste markerregel uit een serieel log, zonder ANSI/terminalrommel
# vóór de marker.
marker_line() {
  local file="$1" pattern="$2"
  [[ -f "$file" ]] || return 0
  grep -a "$pattern" "$file" 2>/dev/null | tail -n 1 | tr -d '\r' \
    | sed -n 's/.*\(LINUXBEOS_[A-Z0-9_]*\)/\1/p'
}

check_marker() {
  local name="$1" file="$2" pattern="$3" required="${4:-}"
  local line
  line="$(marker_line "$file" "$pattern")"
  if [[ -n "$line" ]] && { [[ -z "$required" ]] || [[ "$line" == *"$required"* ]]; }; then
    add_row "$name" PASS "$line"
  else
    add_row "$name" FAIL "marker ontbreekt in ${file#"$PROJECT_ROOT/"}"
  fi
}

step "LinuxBeOS releasematrix"
log "ISO:    $ISO"
log "sha256: $(sha256_of "$ISO")"
log "rapport: $REPORT"

if (( RUN_STATIC )); then
  run_step "statische projectcontrole" "$PROJECT_ROOT/tests/static/check-config.sh"
else
  add_row "statische projectcontrole" SKIP
fi

if (( RUN_SMOKE )); then
  run_step "rooktest UEFI (live)" "$PROJECT_ROOT/tests/test-uefi.sh" "${SMOKE_ARGS[@]}"
  check_marker "sessie + netwerk UEFI" "$TEST_VM_DIR/uefi/serial.log" \
    "LINUXBEOS_SMOKE session=xfce network=connected"
  check_marker "thema UEFI (live)" "$TEST_VM_DIR/uefi/serial.log" \
    "LINUXBEOS_THEME ok" "deskbar=top-right"
  check_marker "thema-integratie via /etc/skel UEFI" "$TEST_VM_DIR/uefi/serial.log" \
    "LINUXBEOS_THEME ok" "skel=ok xdg=ok dark=ok"

  run_step "rooktest BIOS (live)" "$PROJECT_ROOT/tests/test-bios.sh" "${SMOKE_ARGS[@]}"
  check_marker "sessie + netwerk BIOS" "$TEST_VM_DIR/bios/serial.log" \
    "LINUXBEOS_SMOKE session=xfce network=connected"
  check_marker "thema BIOS (live)" "$TEST_VM_DIR/bios/serial.log" \
    "LINUXBEOS_THEME ok" "deskbar=top-right"
  check_marker "thema-integratie via /etc/skel BIOS" "$TEST_VM_DIR/bios/serial.log" \
    "LINUXBEOS_THEME ok" "skel=ok xdg=ok dark=ok"
else
  add_row "rooktest UEFI (live)" SKIP
  add_row "rooktest BIOS (live)" SKIP
fi

if (( RUN_INSTALL )); then
  run_step "Btrfs-installatie UEFI" "$PROJECT_ROOT/tests/test-install-uefi.sh" "${INSTALL_ARGS[@]}"
  check_marker "installatie voltooid UEFI" "$TEST_VM_DIR/install-uefi/install-serial.log" \
    "LINUXBEOS_AUTOINSTALL done"
  check_marker "geïnstalleerd systeem UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_INSTALLED_READY"
  check_marker "thema op doel UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_THEME ok" "deskbar=top-right"
  check_marker "thema via /etc/skel op doel UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_THEME ok" "skel=ok xdg=ok dark=ok"
  check_marker "Btrfs-layout UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_BTRFS_LAYOUT ok" "fstab=subvol,compress=zstd,noatime"
  check_marker "Snapper-snapshot UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_BTRFS_SNAPSHOT ok"
  check_marker "snapshot in GRUB UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_BTRFS_GRUB ok"
  check_marker "boot vanaf snapshot UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_BTRFS_SNAPSHOT_BOOT ok"
  check_marker "rollback + /home behouden UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_BTRFS_ROLLBACK ok" "marker=original home=preserved"
  check_marker "rollbacktest afgerond UEFI" "$TEST_VM_DIR/install-uefi/boot-serial.log" \
    "LINUXBEOS_BTRFS_TEST done"

  run_step "Btrfs-installatie BIOS" "$PROJECT_ROOT/tests/test-install-bios.sh" "${INSTALL_ARGS[@]}"
  check_marker "installatie voltooid BIOS" "$TEST_VM_DIR/install-bios/install-serial.log" \
    "LINUXBEOS_AUTOINSTALL done"
  check_marker "geïnstalleerd systeem BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_INSTALLED_READY"
  check_marker "thema op doel BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_THEME ok" "deskbar=top-right"
  check_marker "thema via /etc/skel op doel BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_THEME ok" "skel=ok xdg=ok dark=ok"
  check_marker "Btrfs-layout BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_BTRFS_LAYOUT ok" "fstab=subvol,compress=zstd,noatime"
  check_marker "Snapper-snapshot BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_BTRFS_SNAPSHOT ok"
  check_marker "snapshot in GRUB BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_BTRFS_GRUB ok"
  check_marker "boot vanaf snapshot BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_BTRFS_SNAPSHOT_BOOT ok"
  check_marker "rollback + /home behouden BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_BTRFS_ROLLBACK ok" "marker=original home=preserved"
  check_marker "rollbacktest afgerond BIOS" "$TEST_VM_DIR/install-bios/boot-serial.log" \
    "LINUXBEOS_BTRFS_TEST done"
else
  add_row "Btrfs-installatie UEFI" SKIP
  add_row "Btrfs-installatie BIOS" SKIP
fi

# De live-look en de look op het doel moeten identiek zijn. Vergelijk de
# themawaarden uit beide sessies (zonder omringende terminalcodes).
THEME_LIVE="$(marker_line "$TEST_VM_DIR/uefi/serial.log" "LINUXBEOS_THEME ok")"
THEME_INSTALLED="$(marker_line "$TEST_VM_DIR/install-uefi/boot-serial.log" "LINUXBEOS_THEME ok")"
if (( RUN_SMOKE && RUN_INSTALL )); then
  if [[ -n "$THEME_LIVE" && "$THEME_LIVE" == "$THEME_INSTALLED" ]]; then
    add_row "geïnstalleerd systeem = live-look" PASS "$THEME_INSTALLED"
  else
    add_row "geïnstalleerd systeem = live-look" FAIL "live=${THEME_LIVE:-onbekend} doel=${THEME_INSTALLED:-onbekend}"
  fi
else
  add_row "geïnstalleerd systeem = live-look" SKIP
fi

# Rapport vastleggen.
if (( RUN_INSTALL )); then
  MATRIX_MODE="volledige releasegate"
elif (( RUN_SMOKE )); then
  MATRIX_MODE="rooktest (geen volledige releasegate)"
else
  MATRIX_MODE="statische controle"
fi
mkdir -p "$(dirname "$REPORT")"
{
  printf '# LinuxBeOS releasematrix\n\n'
  printf -- '- Datum: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- Modus: %s\n' "$MATRIX_MODE"
  printf -- '- ISO: `%s`\n' "$(basename "$ISO")"
  printf -- '- SHA256: `%s`\n' "$(sha256_of "$ISO")"
  printf -- '- Resultaat: **%s**\n\n' "$([[ $FAILURES -eq 0 ]] && echo GESLAAGD || echo MISLUKT)"
  printf '| Controle | Resultaat | Bewijs |\n|---|---|---|\n'
  for row in "${ROWS[@]}"; do
    IFS='|' read -r name status evidence <<<"$row"
    printf '| %s | %s | `%s` |\n' "$name" "$status" "$evidence"
  done
} > "$REPORT"

printf '\n'
if (( FAILURES > 0 )); then
  printf '%sReleasematrix mislukt: %d fout(en), %d overgeslagen.%s\n' \
    "$C_RED" "$FAILURES" "$SKIPS" "$C_RESET" >&2
  printf 'Rapport: %s\n' "$REPORT" >&2
  exit 1
fi
printf '%sReleasematrix geslaagd%s (%d controles, %d overgeslagen).\n' \
  "$C_GREEN" "$C_RESET" "${#ROWS[@]}" "$SKIPS"
printf 'Rapport: %s\n' "$REPORT"
