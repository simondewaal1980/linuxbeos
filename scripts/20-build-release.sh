#!/usr/bin/env bash
# Bouwt en test de complete LinuxBeOS-release met één commando.
#
# Standaard keten:
#   1. host- en projectafhankelijkheden controleren;
#   2. de ISO in de Debian Sid build-VM bouwen;
#   3. de ISO ophalen, SHA256 controleren en releasemetadata schrijven;
#   4. automatisch de statische controle en de UEFI/BIOS-rooktesten draaien.
#
# Met --full wordt daarna ook de volledige releasematrix gedraaid:
# Btrfs-installatie, thema op het doelsysteem, snapshot-boot en rollback op
# zowel UEFI als BIOS. Dat is de releasegate.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

FULL=0
SKIP_BUILD=0
SKIP_HOST_CHECK=0
SKIP_SMOKE=0
KEEP=0
NO_SYNC=0
KEEP_WORKDIR=0
TIMEOUT=""
BUILD_ARGS=()
MATRIX_ARGS=()

usage() {
  cat <<EOF
Gebruik: $0 [opties]

Bouwt de ISO en test hem automatisch. Dit is het ene releasecommando.

Opties:
  --full             Draai na de build de volledige releasematrix
                     (UEFI/BIOS x Btrfs-installatie x thema x rollback)
  --skip-build       Gebruik de bestaande dist/$ISO_NAME
  --skip-smoke       Sla de rooktesten over (alleen statische controle)
  --skip-host-check  Sla scripts/00-check-host.sh over
  --no-sync          Synchroniseer de projectmap niet opnieuw naar de VM
  --keep-workdir     Hergebruik de live-build-werkmap in de VM
  --keep             Bewaar de testartefacten
  --timeout N        Timeout voor SSH/cloud-init van de build-VM
  -h, --help         Deze uitleg
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --full) FULL=1 ;;
    --skip-build) SKIP_BUILD=1 ;;
    --skip-smoke) SKIP_SMOKE=1 ;;
    --skip-host-check) SKIP_HOST_CHECK=1 ;;
    --no-sync) NO_SYNC=1 ;;
    --keep-workdir) KEEP_WORKDIR=1 ;;
    --keep) KEEP=1 ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout vereist een waarde"
      TIMEOUT="$2"; shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done

if (( KEEP )); then
  MATRIX_ARGS+=(--keep)
fi
if [[ -n "$TIMEOUT" ]]; then
  BUILD_ARGS+=(--timeout "$TIMEOUT")
fi
if (( SKIP_HOST_CHECK )); then
  BUILD_ARGS+=(--skip-host-check)
fi
if (( NO_SYNC )); then
  BUILD_ARGS+=(--no-sync)
fi
if (( KEEP_WORKDIR )); then
  BUILD_ARGS+=(--keep-workdir)
fi

mkdir -p "$DIST_DIR"

if (( ! SKIP_BUILD )); then
  step "ISO bouwen"
  "$SCRIPT_DIR/10-build-iso.sh" "${BUILD_ARGS[@]}"
else
  step "Bestaande ISO gebruiken"
  log "--skip-build: $DIST_DIR/$ISO_NAME"
fi

TARGET_ISO="$DIST_DIR/$ISO_NAME"
[[ -f "$TARGET_ISO" ]] || die "ISO niet gevonden: $TARGET_ISO"
ISO_SHA="$(sha256_of "$TARGET_ISO")"
ISO_SIZE="$(du -h "$TARGET_ISO" | awk '{print $1}')"

step "ISO en checksum controleren"
if [[ -f "$DIST_DIR/SHA256SUMS" ]]; then
  ( cd "$DIST_DIR" && sha256sum -c SHA256SUMS )
else
  warn "SHA256SUMS ontbreekt; opnieuw aanmaken"
  ( cd "$DIST_DIR" && sha256sum "$ISO_NAME" > SHA256SUMS )
fi
ok "ISO:     $TARGET_ISO"
ok "grootte: $ISO_SIZE"
ok "sha256:  $ISO_SHA"

step "Releasegate"
MATRIX_ARGS+=(--iso "$TARGET_ISO")
if (( FULL )); then
  log "volledige matrix: statisch + UEFI/BIOS-rooktest + Btrfs-installatie"
  "$PROJECT_ROOT/tests/release-matrix.sh" "${MATRIX_ARGS[@]}"
elif (( SKIP_SMOKE )); then
  log "alleen statische controle"
  "$PROJECT_ROOT/tests/release-matrix.sh" --skip-smoke --skip-install "${MATRIX_ARGS[@]}"
else
  log "statische controle + UEFI/BIOS-rooktest"
  "$PROJECT_ROOT/tests/release-matrix.sh" --skip-install "${MATRIX_ARGS[@]}"
fi

MATRIX_REPORT="$DIST_DIR/release-matrix.txt"
MATRIX_RESULT="geslaagd"
if [[ -f "$MATRIX_REPORT" ]] && grep -q 'Resultaat: \*\*MISLUKT\*\*' "$MATRIX_REPORT"; then
  MATRIX_RESULT="mislukt"
fi

step "Releasemetadata schrijven"
RELEASE_INFO="$DIST_DIR/release-info.txt"
{
  printf 'LinuxBeOS release\n'
  printf '=================\n'
  printf 'distro:        %s %s\n' "$DISTRO_NAME" "$DISTRO_VERSION"
  printf 'status:        %s\n' "$DISTRO_STATUS"
  printf 'architectuur:  %s\n' "$DEBIAN_ARCH"
  printf 'suite:         %s\n' "$DEBIAN_SUITE"
  printf 'ISO:           %s\n' "$ISO_NAME"
  printf 'grootte:       %s\n' "$ISO_SIZE"
  printf 'sha256:        %s\n' "$ISO_SHA"
  printf 'gebouwd:       %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'matrix:        %s\n' "$MATRIX_RESULT"
  printf 'matrixrapport: %s\n' "$(basename "$MATRIX_REPORT")"
  printf 'buildinfo:     build-info.txt\n'
} > "$RELEASE_INFO"

( cd "$DIST_DIR" && sha256sum "$ISO_NAME" > SHA256SUMS )
( cd "$DIST_DIR" && sha256sum -c SHA256SUMS )

step "Klaar"
ok "ISO:          $TARGET_ISO"
ok "sha256:       $ISO_SHA"
ok "release-info: $RELEASE_INFO"
ok "matrix:       $MATRIX_REPORT ($MATRIX_RESULT)"
