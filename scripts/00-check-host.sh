#!/usr/bin/env bash
# Controleert of de host alles heeft om de LinuxBeOS build-VM en de
# UEFI/BIOS-test-VM's te draaien.
#
# De eigenlijke ISO wordt in een Debian Sid build-VM gebouwd; de host hoeft
# dus geen live-build of debootstrap te hebben.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

RUN_STATIC=1
for arg in "$@"; do
  case "$arg" in
    --no-static) RUN_STATIC=0 ;;
    -h|--help)
      cat <<EOF
Gebruik: $0 [--no-static]

Controleert host-afhankelijkheden voor:
  - de Debian Sid build-VM (QEMU/KVM, cloud-init, SSH, rsync)
  - de UEFI/BIOS rooktesten (OVMF, SeaBIOS zit in QEMU)

Met --no-static wordt tests/static/check-config.sh overgeslagen.
EOF
      exit 0
      ;;
    *) die "onbekende optie: $arg" ;;
  esac
done

FAILURES=0
WARNINGS=0

pass() { ok "$*"; }
fail() { printf '%s FAIL %s%s\n' "$C_RED" "$C_RESET" "$*"; FAILURES=$((FAILURES + 1)); }
soft_warn() { warn "$*"; WARNINGS=$((WARNINGS + 1)); }

step "Host commando's"
for cmd in bash qemu-system-x86_64 qemu-img xorriso curl rsync ssh ssh-keygen sha256sum df awk sed grep; do
  if have_cmd "$cmd"; then
    pass "$cmd"
  else
    fail "ontbrekend commando: $cmd"
  fi
done

if [[ -z "$QEMU_IMG" ]]; then
  fail "geen bruikbare qemu-img gevonden"
elif [[ "$QEMU_IMG" != /usr/bin/qemu-img ]]; then
  soft_warn "qemu-img komt niet uit /usr/bin: $QEMU_IMG"
else
  pass "qemu-img: $QEMU_IMG"
fi

step "Virtualisatie"
if kvm_available; then
  pass "/dev/kvm is leesbaar/schrijfbaar"
else
  fail "/dev/kvm niet toegankelijk; voeg de gebruiker toe aan de kvm-groep of regel een ACL"
fi
if grep -qE '(^| )(vmx|svm)( |$)' /proc/cpuinfo; then
  pass "CPU ondersteunt hardware-virtualisatie"
else
  fail "CPU lijkt geen VT-x/AMD-V te ondersteunen"
fi

step "Systeembronnen"
mem_mib=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if (( mem_mib >= BUILD_VM_MEMORY_MB + 2048 )); then
  pass "RAM: ${mem_mib} MiB (build-VM krijgt ${BUILD_VM_MEMORY_MB} MiB)"
elif (( mem_mib >= BUILD_VM_MEMORY_MB )); then
  soft_warn "RAM: ${mem_mib} MiB; weinig marge boven de build-VM van ${BUILD_VM_MEMORY_MB} MiB"
else
  fail "RAM: ${mem_mib} MiB is minder dan de build-VM van ${BUILD_VM_MEMORY_MB} MiB"
fi

cpus=$(nproc)
if (( cpus >= BUILD_VM_CPUS )); then
  pass "CPU's: $cpus (build-VM krijgt $BUILD_VM_CPUS vCPU's)"
else
  soft_warn "CPU's: $cpus; build-VM is geconfigureerd voor $BUILD_VM_CPUS vCPU's"
fi

mkdir -p "$BUILD_DIR" "$CACHE_DIR" "$VM_DIR" "$DIST_DIR" "$TEST_VM_DIR"
free=$(free_mib "$PROJECT_ROOT")
if (( free >= 25000 )); then
  pass "vrije schijfruimte: ${free} MiB"
elif (( free >= 15000 )); then
  soft_warn "vrije schijfruimte: ${free} MiB; minimaal ~25 GiB aanbevolen"
else
  fail "vrije schijfruimte: ${free} MiB; minimaal ~15 GiB nodig"
fi

step "UEFI (OVMF)"
if ovmf_code_path >/dev/null; then
  pass "OVMF code: $(ovmf_code_path)"
else
  fail "OVMF_CODE niet gevonden (installeer ovmf)"
fi
if ovmf_vars_path >/dev/null; then
  pass "OVMF vars: $(ovmf_vars_path)"
else
  fail "OVMF_VARS niet gevonden (installeer ovmf)"
fi
if [[ -x "$QEMU_BIN" ]]; then
  pass "QEMU: $QEMU_BIN"
else
  fail "QEMU niet gevonden"
fi

step "Netwerk en poorten"
if curl -fsI --max-time 20 "$BUILD_VM_BASE_URL" >/dev/null 2>&1; then
  pass "Debian Sid cloud-image bereikbaar"
else
  soft_warn "kon $BUILD_VM_BASE_URL niet bereiken (netwerk of mirror tijdelijk onbereikbaar)"
fi
if vm_is_running; then
  pass "build-VM draait al; SSH-poort $BUILD_VM_SSH_PORT is in gebruik door de VM"
elif have_cmd ss && ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${BUILD_VM_SSH_PORT}$"; then
  fail "TCP-poort $BUILD_VM_SSH_PORT is al in gebruik; kies een andere BUILD_VM_SSH_PORT"
else
  pass "TCP-poort $BUILD_VM_SSH_PORT is vrij"
fi

step "Projectconfiguratie"
if [[ "$DEBIAN_ARCH" != "amd64" ]]; then
  fail "alleen amd64 wordt ondersteund, gevonden: $DEBIAN_ARCH"
else
  pass "architectuur: $DEBIAN_ARCH"
fi
if [[ "$ISO_NAME" =~ ^[a-z0-9.-]+\.iso$ ]]; then
  pass "ISO-naam: $ISO_NAME"
else
  fail "ongeldige ISO-naam: $ISO_NAME"
fi
if [[ -f "$PROJECT_ROOT/build/live-build/auto/config" ]]; then
  pass "live-build auto/config aanwezig"
else
  fail "build/live-build/auto/config ontbreekt"
fi

if (( RUN_STATIC )); then
  step "Statische projectcontrole"
  if [[ -x "$PROJECT_ROOT/tests/static/check-config.sh" ]]; then
    if "$PROJECT_ROOT/tests/static/check-config.sh"; then
      pass "statische controle geslaagd"
    else
      fail "statische controle mislukt"
    fi
  else
    fail "tests/static/check-config.sh ontbreekt of is niet uitvoerbaar"
  fi
fi

printf '\n'
if (( FAILURES > 0 )); then
  printf '%sHostcontrole mislukt: %d fout(en), %d waarschuwing(en).%s\n' "$C_RED" "$FAILURES" "$WARNINGS" "$C_RESET" >&2
  exit 1
fi
printf '%sHostcontrole geslaagd%s (%d waarschuwing(en)).\n' "$C_GREEN" "$C_RESET" "$WARNINGS"
