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
  "build/live-build/config/hooks/live/0200-calamares.chroot"
  "build/live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/99-linuxbeos-autologin.conf"
  "build/live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/99-linuxbeos-live.conf"
  "build/live-build/config/includes.chroot/etc/xdg/autostart/linuxbeos-session-ready.desktop"
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-session-ready"
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installer"
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-autoinstall"
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installed-ready"
  "build/live-build/config/includes.chroot/etc/systemd/system/linuxbeos-installed-ready.service"
  "build/live-build/config/includes.chroot/usr/share/applications/linuxbeos-installer.desktop"
  "installer/calamares/settings.conf"
  "installer/calamares/branding/linuxbeos/branding.desc"
  "installer/calamares/branding/linuxbeos/show.qml"
  "installer/calamares/modules/partition.conf"
  "installer/calamares/modules/users.conf"
  "installer/calamares/modules/unpackfs.conf"
  "installer/calamares/modules/bootloader.conf"
  "installer/calamares/modules/packages.conf"
  "installer/calamares/auto/settings.conf"
  "installer/calamares/auto/modules/partition.conf"
  "installer/calamares/auto/modules/users.conf"
  "scripts/00-check-host.sh"
  "scripts/01-create-build-vm.sh"
  "scripts/10-build-iso.sh"
  "scripts/11-build-iso-in-vm.sh"
  "tests/test-uefi.sh"
  "tests/test-bios.sh"
  "tests/test-install-uefi.sh"
  "tests/test-install-bios.sh"
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
  "build/live-build/config/hooks/live/0200-calamares.chroot" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-session-ready" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installer" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-autoinstall" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installed-ready" \
  "build/live-build/config/includes.chroot/etc/skel/Desktop/install-linuxbeos.desktop" \
  "scripts/00-check-host.sh" \
  "scripts/01-create-build-vm.sh" \
  "scripts/10-build-iso.sh" \
  "scripts/11-build-iso-in-vm.sh" \
  "tests/test-uefi.sh" \
  "tests/test-bios.sh" \
  "tests/test-install-uefi.sh" \
  "tests/test-install-bios.sh" \
  "tests/lib/run-vm-test.sh" \
  "tests/lib/run-install-test.sh" \
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
  "build/live-build/config/hooks/live/0200-calamares.chroot" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-session-ready" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installer" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-autoinstall" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installed-ready"; do
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
for pkg in live-boot live-config-systemd xorg lightdm xfce4 network-manager firefox-esr calamares squashfs-tools xdotool; do
  if grep -qxF "$pkg" "$PROJECT_ROOT/build/live-build/config/package-lists/desktop.list.chroot"; then
    pass "pakket: $pkg"
  else
    fail "pakket ontbreekt in desktop.list.chroot: $pkg"
  fi
done

step "Calamares"
CAL="$PROJECT_ROOT/installer/calamares"
if grep -q 'branding: linuxbeos' "$CAL/settings.conf"; then
  pass "branding linuxbeos geselecteerd"
else
  fail "settings.conf selecteert de branding niet"
fi
for module in partition mount unpackfs fstab locale keyboard users displaymanager bootloader umount; do
  if grep -qE "^[[:space:]]+- ${module}$" "$CAL/settings.conf"; then
    pass "module in keten: $module"
  else
    fail "module ontbreekt in de Calamares-keten: $module"
  fi
done
if grep -q 'run/live/medium/live/filesystem.squashfs' "$CAL/modules/unpackfs.conf"; then
  pass "unpackfs gebruikt de live-squashfs"
else
  fail "unpackfs verwijst niet naar /run/live/medium/live/filesystem.squashfs"
fi
if grep -q 'installEFIFallback: true' "$CAL/modules/bootloader.conf"; then
  pass "EFI-fallbackloader ingeschakeld"
else
  fail "installEFIFallback ontbreekt"
fi
if grep -q 'calamares' "$CAL/modules/packages.conf"; then
  pass "Calamares wordt uit het doel verwijderd"
else
  fail "packages.conf verwijdert Calamares niet"
fi
if grep -q 'initialPartitioningChoice: erase' "$CAL/auto/modules/partition.conf"; then
  pass "auto-test gebruikt erase-schijf"
else
  fail "auto-test selecteert geen erase-schijf"
fi
if grep -q 'value: "testuser"' "$CAL/auto/modules/users.conf"; then
  pass "auto-test gebruikt de vaste testgebruiker"
else
  fail "auto-test heeft geen vaste testgebruiker"
fi
if grep -qxF '    - dialout' "$CAL/modules/users.conf" \
   && grep -qxF '    - dialout' "$CAL/auto/modules/users.conf"; then
  pass "gebruiker krijgt toegang tot de seriële console (dialout)"
else
  fail "dialout ontbreekt in de standaardgroepen"
fi
if grep -q '/home/${USER}/Desktop/install-linuxbeos.desktop' "$CAL/modules/shellprocess-target-cleanup.conf"; then
  pass "installatiepictogram wordt uit de gebruikersmap verwijderd"
else
  fail "opschoning verwijdert het installatiepictogram niet uit /home"
fi
if grep -q 'quit-at-end: true' "$CAL/auto/settings.conf"; then
  pass "auto-test sluit Calamares automatisch af"
else
  fail "auto-test heeft quit-at-end niet ingeschakeld"
fi
if grep -q 'CALAMARES_SRC' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh"; then
  pass "buildscript neemt installer/calamares op in de ISO"
else
  fail "buildscript kopieert installer/calamares niet"
fi

step "Live-sessie"
LIGHTDM_CONF="$PROJECT_ROOT/build/live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/99-linuxbeos-live.conf"
if grep -qxF "user-session=xfce" "$LIGHTDM_CONF"; then
  pass "LightDM-sessie is xfce"
else
  fail "LightDM-sessie is niet xfce"
fi
LIGHTDM_AUTOLOGIN="$PROJECT_ROOT/build/live-build/config/includes.chroot/etc/lightdm/lightdm.conf.d/99-linuxbeos-autologin.conf"
if grep -qxF "autologin-user=$LIVE_USER" "$LIGHTDM_AUTOLOGIN"; then
  pass "LightDM-autologin voor $LIVE_USER"
else
  fail "LightDM-autologin voor $LIVE_USER ontbreekt"
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
if grep -qE '^[[:space:]]*insmod[[:space:]]+efi_uga' "$PROJECT_ROOT/build/live-build/config/bootloaders/grub-pc/config.cfg"; then
  fail "GRUB-override bevat nog insmod efi_uga (niet beschikbaar in GRUB 2.14)"
else
  pass "GRUB-override vermijdt efi_uga"
fi
if grep -qE '^[[:space:]]*set[[:space:]]+timeout=' "$PROJECT_ROOT/build/live-build/config/bootloaders/grub-pc/config.cfg"; then
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
