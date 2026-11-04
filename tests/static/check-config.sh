#!/usr/bin/env bash
# Statische controle van de repository: bestanden, rechten, shell-syntax en
# de belangrijkste live-build-koppelingen. Draait zonder root en zonder VM.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/lib/common.sh
. "$SCRIPT_DIR/../../scripts/lib/common.sh"

FAILURES=0
fail() { printf '%s FAIL %s%s\n' "$C_RED" "$C_RESET" "$*"; FAILURES=$((FAILURES + 1)); }
pass() { printf '%s  OK  %s%s\n' "$C_GREEN" "$C_RESET" "$*"; }

step "Verplichte bestanden"
required_files=(
  "config/project.conf"
  "build/live-build/auto/config"
  "build/live-build/config/package-lists/desktop.list.chroot"
  "build/live-build/config/bootloaders/grub-pc/config.cfg"
  "build/live-build/config/hooks/live/0100-services.chroot"
  "build/live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/99-linuxbeos-autologin.conf"
  "build/live-build/config/includes.chroot/etc/xdg/autostart/linuxbeos-session-ready.desktop"
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-session-ready"
  "scripts/00-check-host.sh"
  "scripts/01-create-build-vm.sh"
  "scripts/10-build-iso.sh"
  "scripts/11-build-iso-in-vm.sh"
  "tests/test-uefi.sh"
  "tests/test-bios.sh"
  "docs/development-progress.md"
)
for f in "${required_files[@]}"; do
  if [[ -f "$PROJECT_ROOT/$f" ]]; then
    pass "$f"
  else
    fail "ontbreekt: $f"
  fi
done

step "Uitvoerbare bestanden"
for f in \
  "build/live-build/auto/config" \
  "build/live-build/config/hooks/live/0100-services.chroot" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-session-ready" \
  "scripts/00-check-host.sh" \
  "scripts/01-create-build-vm.sh" \
  "scripts/10-build-iso.sh" \
  "scripts/11-build-iso-in-vm.sh" \
  "tests/test-uefi.sh" \
  "tests/test-bios.sh" \
  "tests/lib/run-vm-test.sh" \
  "tests/static/check-config.sh"; do
  if [[ -x "$PROJECT_ROOT/$f" ]]; then
    pass "$f is uitvoerbaar"
  else
    fail "niet uitvoerbaar: $f"
  fi
done

step "Shell-syntax"
while IFS= read -r -d '' f; do
  if bash -n "$f" 2>/dev/null; then
    pass "bash -n ${f#"$PROJECT_ROOT/"}"
  else
    fail "syntaxfout in ${f#"$PROJECT_ROOT/"}"
  fi
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/tests" -name '*.sh' -type f -print0)

for f in \
  "build/live-build/auto/config" \
  "build/live-build/config/hooks/live/0100-services.chroot" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-session-ready"; do
  if sh -n "$PROJECT_ROOT/$f" 2>/dev/null; then
    pass "sh -n $f"
  else
    fail "POSIX-sh syntaxfout in $f"
  fi
done

step "Configuratie"
if [[ "$DEBIAN_ARCH" == "amd64" ]]; then
  pass "architectuur amd64"
else
  fail "architectuur is geen amd64: $DEBIAN_ARCH"
fi
if [[ "$ISO_NAME" =~ ^[a-z0-9][a-z0-9.-]*\.iso$ ]]; then
  pass "ISO-naam: $ISO_NAME"
else
  fail "ongeldige ISO-naam: $ISO_NAME"
fi
if [[ "$LIVE_BOOTAPPEND" == *"username=$LIVE_USER"* ]]; then
  pass "live-gebruiker in bootappend: $LIVE_USER"
else
  fail "LIVE_BOOTAPPEND bevat niet username=$LIVE_USER"
fi
if [[ "$LIVE_BOOTAPPEND" == *"console=ttyS0"* ]]; then
  pass "seriële console in bootappend (nodig voor rooktesten)"
else
  fail "LIVE_BOOTAPPEND mist console=ttyS0"
fi

step "Pakketlijst"
for pkg in live-boot live-config-systemd xorg lightdm xfce4 network-manager firefox-esr; do
  if grep -qxF "$pkg" "$PROJECT_ROOT/build/live-build/config/package-lists/desktop.list.chroot"; then
    pass "pakket: $pkg"
  else
    fail "pakket ontbreekt in desktop.list.chroot: $pkg"
  fi
done

step "Live-sessie"
LIGHTDM_CONF="$PROJECT_ROOT/build/live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/99-linuxbeos-autologin.conf"
if grep -qxF "autologin-user=$LIVE_USER" "$LIGHTDM_CONF"; then
  pass "LightDM-autologin voor $LIVE_USER"
else
  fail "LightDM-autologin voor $LIVE_USER ontbreekt"
fi
if grep -qxF "user-session=xfce" "$LIGHTDM_CONF"; then
  pass "LightDM-sessie is xfce"
else
  fail "LightDM-sessie is niet xfce"
fi

step "Build-scripts"
if grep -q -- '--bootloaders' "$PROJECT_ROOT/build/live-build/auto/config"; then
  pass "UEFI+BIOS via --bootloaders"
else
  fail "auto/config bevat geen UEFI+BIOS-bootloaderconfiguratie"
fi
if grep -q 'grub-efi' "$PROJECT_ROOT/build/live-build/auto/config"; then
  pass "GRUB EFI geconfigureerd"
else
  fail "GRUB EFI ontbreekt in auto/config"
fi
if grep -q 'grub-pc' "$PROJECT_ROOT/build/live-build/auto/config"; then
  pass "GRUB PC (BIOS) geconfigureerd"
else
  fail "GRUB PC ontbreekt in auto/config"
fi
if grep -q 'insmod efi_uga' "$PROJECT_ROOT/build/live-build/config/bootloaders/grub-pc/config.cfg"; then
  fail "GRUB-override bevat nog insmod efi_uga (niet beschikbaar in GRUB 2.14)"
else
  pass "GRUB-override vermijdt efi_uga"
fi
if grep -q 'set timeout=' "$PROJECT_ROOT/build/live-build/config/bootloaders/grub-pc/config.cfg"; then
  pass "GRUB automatische timeout ingesteld"
else
  fail "GRUB-timeout ontbreekt; het menu blijft anders oneindig wachten"
fi

printf '\n'
if (( FAILURES > 0 )); then
  printf '%sStatische controle mislukt: %d fout(en).%s\n' "$C_RED" "$FAILURES" "$C_RESET" >&2
  exit 1
fi
printf '%sStatische controle geslaagd.%s\n' "$C_GREEN" "$C_RESET"
