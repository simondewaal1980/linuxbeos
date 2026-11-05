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
  "build/live-build/config/hooks/live/0300-theme.chroot"
  "build/live-build/config/hooks/live/0400-apps.chroot"
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
  "installer/calamares/modules/mount.conf"
  "installer/calamares/modules/fstab.conf"
  "installer/calamares/modules/users.conf"
  "installer/calamares/modules/unpackfs.conf"
  "installer/calamares/modules/bootloader.conf"
  "installer/calamares/modules/packages.conf"
  "installer/calamares/modules/services-systemd.conf"
  "installer/calamares/auto/settings.conf"
  "installer/calamares/auto/modules/partition.conf"
  "installer/calamares/auto/modules/users.conf"
  "installer/calamares/auto/modules/services-systemd.conf"
  "installer/calamares/auto/modules/shellprocess-target-cleanup.conf"
  "btrfs/snapper/root"
  "btrfs/snapper/default"
  "btrfs/grub.d/41_snapshots-btrfs"
  "btrfs/bin/linuxbeos-rollback"
  "btrfs/bin/linuxbeos-update-grub"
  "btrfs/bin/linuxbeos-btrfs-test"
  "btrfs/systemd/grub-btrfs.service"
  "btrfs/systemd/grub-btrfs.path"
  "btrfs/systemd/linuxbeos-btrfs-test.service"
  "desktop/xfwm4/themerc"
  "desktop/xfwm4/title-active-stretch.png"
  "desktop/xfwm4/close-active.png"
  "desktop/xfwm4/close-active.xpm"
  "desktop/gtk/index.theme"
  "desktop/gtk/gtk-2.0/gtkrc"
  "desktop/gtk/gtk-3.0/gtk.css"
  "desktop/gtk/dark/index.theme"
  "desktop/gtk/dark/gtk-2.0/gtkrc"
  "desktop/gtk/dark/gtk-3.0/gtk.css"
  "desktop/icons/LinuxBeOS/index.theme"
  "desktop/icons/LinuxBeOS/scalable/apps/linuxbeos-logo.svg"
  "desktop/icons/LinuxBeOS/scalable/places/user-trash.svg"
  "desktop/cursors/LinuxBeOS/cursor.theme"
  "desktop/cursors/LinuxBeOS/cursors/left_ptr"
  "desktop/backgrounds/linuxbeos-wallpaper.png"
  "desktop/backgrounds/linuxbeos-greeter.png"
  "desktop/LICENSE"
  "desktop/NOTICE.md"
  "overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
  "overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
  "overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
  "overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
  "overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml"
  "overlays/etc/lightdm/lightdm-gtk-greeter.conf.d/99-linuxbeos.conf"
  "overlays/etc/zsh/linuxbeos.zsh"
  "overlays/etc/skel/.zshrc"
  "overlays/usr/local/bin/linuxbeos-theme-apply"
  "overlays/usr/local/bin/linuxbeos-theme-check"
  "overlays/usr/local/bin/linuxbeos-theme-demo"
  "overlays/usr/local/bin/linuxbeos-theme-mode"
  "overlays/etc/xdg/autostart/10-linuxbeos-theme-apply.desktop"
  "overlays/etc/xdg/autostart/15-linuxbeos-theme-demo.desktop"
  "overlays/etc/xdg/autostart/20-linuxbeos-theme-check.desktop"
  "scripts/00-check-host.sh"
  "scripts/01-create-build-vm.sh"
  "scripts/10-build-iso.sh"
  "scripts/11-build-iso-in-vm.sh"
  "scripts/20-build-release.sh"
  "tests/test-uefi.sh"
  "tests/test-bios.sh"
  "tests/test-install-uefi.sh"
  "tests/test-install-bios.sh"
  "tests/release-matrix.sh"
  "docs/development-progress.md"
  "docs/btrfs-layout.md"
  "docs/theme.md"
  "docs/installation.md"
  "docs/release.md"
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
  "build/live-build/config/hooks/live/0300-theme.chroot" \
  "build/live-build/config/hooks/live/0400-apps.chroot" \
  "overlays/usr/local/bin/linuxbeos-theme-apply" \
  "overlays/usr/local/bin/linuxbeos-theme-check" \
  "overlays/usr/local/bin/linuxbeos-theme-demo" \
  "overlays/usr/local/bin/linuxbeos-theme-mode" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-session-ready" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installer" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-autoinstall" \
  "build/live-build/config/includes.chroot/usr/local/bin/linuxbeos-installed-ready" \
  "build/live-build/config/includes.chroot/etc/skel/Desktop/install-linuxbeos.desktop" \
  "btrfs/grub.d/41_snapshots-btrfs" \
  "btrfs/bin/linuxbeos-rollback" \
  "btrfs/bin/linuxbeos-update-grub" \
  "btrfs/bin/linuxbeos-btrfs-test" \
  "scripts/00-check-host.sh" \
  "scripts/01-create-build-vm.sh" \
  "scripts/10-build-iso.sh" \
  "scripts/11-build-iso-in-vm.sh" \
  "scripts/20-build-release.sh" \
  "tests/test-uefi.sh" \
  "tests/test-bios.sh" \
  "tests/test-install-uefi.sh" \
  "tests/test-install-bios.sh" \
  "tests/release-matrix.sh" \
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

for f in "$PROJECT_ROOT"/btrfs/bin/* "$PROJECT_ROOT"/btrfs/grub.d/*; do
  [[ -f "$f" ]] || continue
  if bash -n "$f" 2>/dev/null; then
    pass "bash -n ${f#"$PROJECT_ROOT/"}"
  else
    fail "syntaxfout in ${f#"$PROJECT_ROOT/"}"
  fi
done

for f in \
  "build/live-build/auto/config" \
  "build/live-build/config/hooks/live/0100-services.chroot" \
  "build/live-build/config/hooks/live/0200-calamares.chroot" \
  "build/live-build/config/hooks/live/0300-theme.chroot" \
  "build/live-build/config/hooks/live/0400-apps.chroot" \
  "overlays/usr/local/bin/linuxbeos-theme-apply" \
  "overlays/usr/local/bin/linuxbeos-theme-check" \
  "overlays/usr/local/bin/linuxbeos-theme-demo" \
  "overlays/usr/local/bin/linuxbeos-theme-mode" \
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

step "Btrfs, Snapper en rollback"
PART_PROD="$CAL/modules/partition.conf"
PART_AUTO="$CAL/auto/modules/partition.conf"
MOUNT_CONF="$CAL/modules/mount.conf"
if grep -q 'defaultFileSystemType: "btrfs"' "$PART_PROD"; then
  pass "productie installeert standaard op Btrfs"
else
  fail "productieconfiguratie gebruikt geen Btrfs als standaard"
fi
if grep -q 'defaultFileSystemType: "btrfs"' "$PART_AUTO"; then
  pass "installatietest gebruikt Btrfs"
else
  fail "auto-installatietest gebruikt geen Btrfs"
fi
for subvol in "$BTRFS_ROOT_SUBVOL" "$BTRFS_HOME_SUBVOL" "$BTRFS_SNAPSHOTS_SUBVOL" \
              "$BTRFS_VAR_LOG_SUBVOL" "$BTRFS_VAR_CACHE_SUBVOL"; do
  if grep -qE "^[[:space:]]+subvolume: /${subvol}$" "$MOUNT_CONF"; then
    pass "subvolume in mount.conf: /$subvol"
  else
    fail "subvolume ontbreekt in mount.conf: /$subvol"
  fi
done
if grep -q "btrfsSwapSubvol: /${BTRFS_SWAP_SUBVOL}" "$MOUNT_CONF"; then
  pass "swap-subvolume in mount.conf: /$BTRFS_SWAP_SUBVOL"
else
  fail "btrfsSwapSubvol ontbreekt in mount.conf"
fi
if grep -q 'compress=zstd' "$MOUNT_CONF" && grep -q 'noatime' "$MOUNT_CONF"; then
  pass "Btrfs-mountopties bevatten compress=zstd en noatime"
else
  fail "Btrfs-mountopties ontbreken in mount.conf"
fi
if grep -qE '^mountOptions:' "$CAL/modules/fstab.conf"; then
  fail "fstab.conf bevat mountOptions; die horen in mount.conf"
else
  pass "fstab.conf laat mountopties aan de mount-module"
fi
for pkg in btrfs-progs snapper; do
  if grep -qxF "$pkg" "$PROJECT_ROOT/build/live-build/config/package-lists/desktop.list.chroot"; then
    pass "pakket: $pkg"
  else
    fail "pakket ontbreekt in desktop.list.chroot: $pkg"
  fi
done
SNAPPER_CONF="$PROJECT_ROOT/btrfs/snapper/root"
if grep -qxF 'TIMELINE_CREATE="yes"' "$SNAPPER_CONF" \
   && grep -qxF 'NUMBER_CLEANUP="yes"' "$SNAPPER_CONF"; then
  pass "Snapper: tijdlijn en nummer-opruiming ingeschakeld"
else
  fail "Snapper-configuratie mist tijdlijn- of opruiminstellingen"
fi
if grep -qxF 'SNAPPER_CONFIGS="root"' "$PROJECT_ROOT/btrfs/snapper/default"; then
  pass "Snapper-configuratie 'root' is actief in /etc/default/snapper"
else
  fail "SNAPPER_CONFIGS staat niet op root in /etc/default/snapper"
fi
if grep -q 'snapper-timeline.timer' "$CAL/modules/services-systemd.conf" \
   && grep -q 'snapper-cleanup.timer' "$CAL/modules/services-systemd.conf" \
   && grep -q 'grub-btrfs.path' "$CAL/modules/services-systemd.conf"; then
  pass "Snapper-timers en grub-btrfs zijn ingeschakeld"
else
  fail "Snapper-timers of grub-btrfs ontbreken in services-systemd.conf"
fi
if grep -q 'linuxbeos-btrfs-test.service' "$CAL/auto/modules/services-systemd.conf"; then
  pass "Btrfs-rollbacktest is in de testvariant ingeschakeld"
else
  fail "Btrfs-rollbacktest is niet ingeschakeld in de testvariant"
fi
if grep -q 'rm -f /usr/local/bin/linuxbeos-btrfs-test' "$CAL/modules/shellprocess-target-cleanup.conf" \
   && ! grep -q 'rm -f /usr/local/bin/linuxbeos-btrfs-test' "$CAL/auto/modules/shellprocess-target-cleanup.conf"; then
  pass "Btrfs-testhulp wordt alleen in de productie-opruiming verwijderd"
else
  fail "Btrfs-testhulp ontbreekt in de productie-opruiming of wordt in de testvariant verwijderd"
fi
if grep -q 'BTRFS_SRC' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q '41_snapshots-btrfs' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q 'BTRFS_SUBVOLUMES=' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh"; then
  pass "buildscript neemt btrfs/-configuratie op in de ISO"
else
  fail "buildscript kopieert btrfs/ niet naar de ISO"
fi
if grep -q 'rootflags=subvol=' "$PROJECT_ROOT/btrfs/grub.d/41_snapshots-btrfs" \
   && grep -q '\-\-id "linuxbeos-snapshot-' "$PROJECT_ROOT/btrfs/grub.d/41_snapshots-btrfs" \
   && grep -q ' ro ' "$PROJECT_ROOT/btrfs/grub.d/41_snapshots-btrfs" \
   && grep -q 'findmnt -no TARGET --target /boot' "$PROJECT_ROOT/btrfs/grub.d/41_snapshots-btrfs"; then
  pass "GRUB-generator maakt read-only snapshot-entries met een vaste id"
else
  fail "GRUB-generator mist rootflags, id, read-only snapshot-entry of de /boot-controle"
fi
if grep -q -- '--device' "$PROJECT_ROOT/btrfs/bin/linuxbeos-rollback" \
   && grep -q 'subvolid=5' "$PROJECT_ROOT/btrfs/bin/linuxbeos-rollback" \
   && grep -q 'broken-' "$PROJECT_ROOT/btrfs/bin/linuxbeos-rollback" \
   && grep -q 'findmnt -no SOURCE' "$PROJECT_ROOT/btrfs/bin/linuxbeos-rollback"; then
  pass "rollbackscript kan vanaf snapshot/live-ISO en bewaart de oude root"
else
  fail "rollbackscript mist --device, subvolid=5, de oude-root-backup of apparaatdetectie"
fi
if grep -q 'LINUXBEOS_BTRFS_TEST done' "$PROJECT_ROOT/tests/lib/run-install-test.sh"; then
  pass "installatietest wacht op de Btrfs-rollbackmarkering"
else
  fail "installatietest controleert de Btrfs-rollback niet"
fi
if grep -q 'Rollback' "$PROJECT_ROOT/docs/btrfs-layout.md"; then
  pass "Btrfs-layoutdocumentatie beschrijft de rollback"
else
  fail "docs/btrfs-layout.md mist de rollbackprocedure"
fi

step "BeOS-thema"
XFWM_THEME="$PROJECT_ROOT/desktop/xfwm4/themerc"
if grep -qxF 'full_width_title=true' "$XFWM_THEME"; then
  pass "xfwm4 gebruikt een volledige titeltab"
else
  fail "xfwm4-thema mist full_width_title=true"
fi
if grep -qxF 'button_layout=C|M' "$XFWM_THEME"; then
  pass "xfwm4-knoppen: sluiten links, zoom rechts"
else
  fail "xfwm4-thema mist de BeOS-knoppenindeling C|M"
fi
if [[ -f "$PROJECT_ROOT/desktop/xfwm4/title-active-stretch.png" ]] \
   && [[ -f "$PROJECT_ROOT/desktop/xfwm4/title-active-stretch.xpm" ]]; then
  pass "xfwm4 heeft stretch- en XPM-fallback voor de titeltab"
else
  fail "title-active-stretch ontbreekt (PNG of XPM)"
fi
if grep -q '^active_text_color=#101010' "$XFWM_THEME"; then
  pass "xfwm4 gebruikt zwarte tekst op de gele tab"
else
  fail "active_text_color ontbreekt of is niet zwart"
fi

XSETTINGS="$PROJECT_ROOT/overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
if grep -q 'name="ThemeName" type="string" value="LinuxBeOS"' "$XSETTINGS"; then
  pass "GTK-thema LinuxBeOS is de standaard"
else
  fail "xsettings.xml selecteert het GTK-thema niet"
fi
if grep -q 'name="IconThemeName" type="string" value="LinuxBeOS"' "$XSETTINGS"; then
  pass "icoonthema LinuxBeOS is de standaard"
else
  fail "xsettings.xml selecteert het icoonthema niet"
fi
if grep -q 'name="CursorThemeName" type="string" value="LinuxBeOS"' "$XSETTINGS"; then
  pass "cursorthema LinuxBeOS is de standaard"
else
  fail "xsettings.xml selecteert het cursorthema niet"
fi
if grep -q 'value="Liberation Sans 10"' "$XSETTINGS"; then
  pass "BeOS-achtige systeemfont gekozen (Liberation Sans)"
else
  fail "xsettings.xml mist de systeemfontkeuze"
fi

XFWM_XML="$PROJECT_ROOT/overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
if grep -q 'name="theme" type="string" value="LinuxBeOS"' "$XFWM_XML"; then
  pass "xfwm4 gebruikt het LinuxBeOS-vensterdecoratie"
else
  fail "xfwm4.xml selecteert het thema niet"
fi

PANEL_XML="$PROJECT_ROOT/overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
if grep -q 'name="position" type="string" value="p=2;x=0;y=0"' "$PANEL_XML"; then
  pass "Deskbar staat rechtsboven"
else
  fail "Deskbarpositie is niet rechtsboven (p=2)"
fi
for plugin in applicationsmenu tasklist clock; do
  if grep -q "value=\"$plugin\"" "$PANEL_XML"; then
    pass "Deskbar-plugin: $plugin"
  else
    fail "Deskbar-plugin ontbreekt: $plugin"
  fi
done
if grep -q 'name="expand" type="bool" value="true"' "$PANEL_XML"; then
  pass "vensterlijst vult de ruimte tussen menu en klok"
else
  fail "tasklist heeft geen expand=true"
fi
if grep -q 'name="mode" type="uint" value="2"' "$PANEL_XML"; then
  pass "klok staat in digitale modus"
else
  fail "klokmodus is niet digitaal (2)"
fi
if grep -q 'name="background-style" type="uint" value="0"' "$PANEL_XML" \
   && ! grep -q 'name="background-rgba"' "$PANEL_XML"; then
  pass "Deskbar volgt de themakleuren (geen vaste lichte achtergrond)"
else
  fail "Deskbar heeft een vaste achtergrond die in donkere modus licht blijft"
fi
if grep -q 'xfce4-panel' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-mode" \
   && grep -q 'background-style' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-mode"; then
  pass "thema-wissel laat de Deskbar met het GTK-thema meewisselen"
else
  fail "thema-wissel herstelt een vaste paneelachtergrond niet"
fi
if grep -q 'panel-background' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check"; then
  pass "themacontrole bewaakt dat de Deskbar de themakleuren volgt"
else
  fail "themacontrole controleert de paneelachtergrond niet"
fi
DESKTOP_XML="$PROJECT_ROOT/overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
if grep -q 'value="/usr/share/backgrounds/linuxbeos/linuxbeos-wallpaper.png"' "$DESKTOP_XML"; then
  pass "BeOS-achtergrond is de standaard"
else
  fail "xfce4-desktop.xml verwijst niet naar de LinuxBeOS-achtergrond"
fi
if grep -q 'name="style" type="int" value="2"' "$DESKTOP_XML"; then
  pass "bureaubladpictogrammen (file-icons) zijn ingeschakeld"
else
  fail "xfce4-desktop.xml zet de pictogramstijl niet op file-icons (2)"
fi
if grep -q 'name="show-trash" type="bool" value="true"' "$DESKTOP_XML"; then
  pass "prullenbak op het bureaublad"
else
  fail "prullenbakpictogram ontbreekt in xfce4-desktop.xml"
fi

if grep -q 'DESKTOP_SRC' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q 'OVERLAYS_SRC' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q 'usr/share/themes/LinuxBeOS' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh"; then
  pass "buildscript neemt desktop/ en overlays/ op in de ISO"
else
  fail "buildscript kopieert de thema-assets of overlays niet"
fi

DARK_GTK3="$PROJECT_ROOT/desktop/gtk/dark/gtk-3.0/gtk.css"
DARK_GTK2="$PROJECT_ROOT/desktop/gtk/dark/gtk-2.0/gtkrc"
DARK_INDEX="$PROJECT_ROOT/desktop/gtk/dark/index.theme"
if [[ -f "$DARK_GTK3" ]] && [[ -f "$DARK_GTK2" ]] && [[ -f "$DARK_INDEX" ]]; then
  pass "donkere GTK-variant aanwezig (GTK2, GTK3 en index.theme)"
else
  fail "donkere GTK-variant mist een van de themabestanden"
fi
if grep -q '@define-color theme_bg_color #303030' "$DARK_GTK3" \
   && grep -q '@define-color theme_tooltip_fg_color #fff7a8' "$DARK_GTK3" \
   && grep -q 'gtk-color-scheme = "bg_color:#303030' "$DARK_GTK2"; then
  pass "donkere GTK-variant gebruikt het donkergrijze BeOS-palet"
else
  fail "donkere GTK-variant gebruikt niet het verwachte palet"
fi
if grep -q 'LinuxBeOS-Dark' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q 'themes/LinuxBeOS-Dark' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check"; then
  pass "buildscript en themacontrole kennen de donkere variant"
else
  fail "donkere variant is niet in build of themacontrole opgenomen"
fi
if grep -q 'LinuxBeOS-Dark' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-mode" \
   && grep -q 'toggle' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-mode"; then
  pass "thema-wisselcommando ondersteunt licht, donker en toggle"
else
  fail "thema-wisselcommando voor de donkere variant ontbreekt"
fi
if grep -q 'LINUXBEOS_THEME ok' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check" \
   && grep -q 'dark=' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check"; then
  pass "themacontrole schrijft een seriële marker inclusief dark=ok"
else
  fail "themacontrole mist de LINUXBEOS_THEME-marker of dark=ok"
fi
if grep -q 'THEME_REQUIRED' "$PROJECT_ROOT/tests/lib/run-vm-test.sh" \
   && grep -q 'LINUXBEOS_THEME' "$PROJECT_ROOT/tests/lib/run-vm-test.sh"; then
  pass "rooktest vereist het thema (met --skip-theme als diagnosemaatregel)"
else
  fail "rooktest controleert het thema niet"
fi
if grep -q 'dark=ok' "$PROJECT_ROOT/tests/lib/run-vm-test.sh" \
   && grep -q 'dark=ok' "$PROJECT_ROOT/tests/lib/run-install-test.sh"; then
  pass "rook- en installatietest eisen de donkere variant (dark=ok)"
else
  fail "rook- of installatietest controleert de donkere variant niet"
fi
if [[ -f "$PROJECT_ROOT/desktop/LICENSE" ]] && [[ -f "$PROJECT_ROOT/desktop/NOTICE.md" ]]; then
  pass "licentie en herkomst van de thema-assets vastgelegd"
else
  fail "desktop/LICENSE of desktop/NOTICE.md ontbreekt"
fi
if grep -qxF 'fonts-liberation2' "$PROJECT_ROOT/build/live-build/config/package-lists/desktop.list.chroot"; then
  pass "pakket fonts-liberation2 aanwezig"
else
  fail "fonts-liberation2 ontbreekt in de pakketlijst"
fi
if grep -qxF 'librsvg2-common' "$PROJECT_ROOT/build/live-build/config/package-lists/desktop.list.chroot"; then
  pass "SVG-rendering (librsvg2-common) aanwezig"
else
  fail "librsvg2-common ontbreekt in de pakketlijst"
fi

step "Shell en extra software"
for pkg in zsh git curl ca-certificates gnupg unzip; do
  if grep -qxF "$pkg" "$PROJECT_ROOT/build/live-build/config/package-lists/desktop.list.chroot"; then
    pass "pakket: $pkg"
  else
    fail "pakket ontbreekt in desktop.list.chroot: $pkg"
  fi
done
for conf in \
  "$PROJECT_ROOT/installer/calamares/modules/users.conf" \
  "$PROJECT_ROOT/installer/calamares/auto/modules/users.conf"; do
  if grep -q 'shell: /bin/zsh' "$conf"; then
    pass "ZSH als standaardshell: ${conf#"$PROJECT_ROOT/"}"
  else
    fail "ZSH-standaardshell ontbreekt in ${conf#"$PROJECT_ROOT/"}"
  fi
done
ZSH_CONF="$PROJECT_ROOT/overlays/etc/zsh/linuxbeos.zsh"
for needle in 'LINUXBEOS_NAME' 'vcs_info' 'git:(' 'compinit' \
              '_linuxbeos_precmd' 'add-zsh-hook' '_linuxbeos_status_segment' \
              'RPROMPT' 'git status --short --branch'; do
  if grep -qF "$needle" "$ZSH_CONF"; then
    pass "ZSH-config bevat: $needle"
  else
    fail "ZSH-config mist: $needle"
  fi
done
if grep -qF '/etc/zsh/linuxbeos.zsh' "$PROJECT_ROOT/overlays/etc/skel/.zshrc"; then
  pass "/etc/skel/.zshrc laadt de gedeelde ZSH-config"
else
  fail "/etc/skel/.zshrc laadt de gedeelde ZSH-config niet"
fi
APPS_HOOK="$PROJECT_ROOT/build/live-build/config/hooks/live/0400-apps.chroot"
for needle in 'DSHELL=/bin/zsh' 'google-chrome-stable' 'OPENCODE_SHA256_AMD64' '/usr/local/bin/opencode'; do
  if grep -qF "$needle" "$APPS_HOOK"; then
    pass "software-hook bevat: $needle"
  else
    fail "software-hook mist: $needle"
  fi
done
if grep -q '^OPENCODE_VERSION=' "$PROJECT_ROOT/config/project.conf" \
   && grep -q '^OPENCODE_SHA256_AMD64=' "$PROJECT_ROOT/config/project.conf" \
   && grep -q '^GOOGLE_CHROME_REPO=' "$PROJECT_ROOT/config/project.conf"; then
  pass "opencode-versie, SHA256 en Chrome-repo staan in project.conf"
else
  fail "software-instellingen ontbreken in config/project.conf"
fi
if grep -q 'identity.conf' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q 'software.conf' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q 'OPENCODE_VERSION' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh"; then
  pass "buildscript genereert shell- en software-identiteit"
else
  fail "buildscript genereert identity.conf/software.conf niet"
fi
if grep -q 'command -v "$bin"' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check" \
   && grep -q 'google-chrome-stable' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check"; then
  pass "sessiecontrole verifieert git, opencode en Chrome"
else
  fail "sessiecontrole verifieert de extra software niet"
fi

# Controleer dat alle relatieve symlinks in het icoonthema naar bestaande
# bestanden wijzen; een gebroken alias geeft anders ontbrekende iconen.
broken_links=0
while IFS= read -r -d '' link; do
  target="$(readlink "$link")"
  if [[ ! -e "$(dirname "$link")/$target" ]]; then
    fail "gebroken icoonsymlink: ${link#"$PROJECT_ROOT/"}"
    broken_links=$((broken_links + 1))
  fi
done < <(find "$PROJECT_ROOT/desktop/icons/LinuxBeOS" -type l -print0)
if (( broken_links == 0 )); then
  pass "alle icoonsymlinks zijn geldig"
fi

if command -v xmllint >/dev/null 2>&1; then
  for xml in "$PROJECT_ROOT"/overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/*.xml; do
    if xmllint --noout "$xml" 2>/dev/null; then
      pass "XML geldig: ${xml#"$PROJECT_ROOT/"}"
    else
      fail "ongeldige XML: ${xml#"$PROJECT_ROOT/"}"
    fi
  done
else
  warn "xmllint ontbreekt; XML-controle overgeslagen"
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

step "Fase 4: integratie en releasegate"
BRANDING="$PROJECT_ROOT/installer/calamares/branding/linuxbeos"
if grep -q 'SidebarBackgroundCurrent: "#f5e64b"' "$BRANDING/branding.desc" \
   && grep -q 'SidebarBackground:        "#d6d6d6"' "$BRANDING/branding.desc"; then
  pass "Calamares-branding gebruikt het BeOS-grijs/geel-palet"
else
  fail "Calamares-branding gebruikt niet het BeOS-palet"
fi
if grep -q 'Btrfs + Snapper' "$BRANDING/show.qml" \
   && grep -q 'BeOS 5-look' "$BRANDING/show.qml"; then
  pass "Calamares-slideshow vertelt de pijlers (Debian, Btrfs, BeOS)"
else
  fail "Calamares-slideshow mist de distributiepijlers"
fi
if grep -q 'fase 1' "$BRANDING/welcome.svg" 2>/dev/null \
   || grep -qi 'ext4' "$BRANDING/welcome.svg" 2>/dev/null; then
  fail "Calamares-welcome bevat nog een fase 1/ext4-verwijzing"
else
  pass "Calamares-welcome is bijgewerkt voor de Btrfs-release"
fi
if grep -q 'SKEL_XFCE' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh" \
   && grep -q '/etc/skel/.config/xfce4/xfconf' "$PROJECT_ROOT/scripts/11-build-iso-in-vm.sh"; then
  pass "buildscript plaatst xfconf-standaarden in /etc/skel"
else
  fail "buildscript vult /etc/skel niet met de xfconf-standaarden"
fi
if grep -q 'skel=' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check" \
   && grep -q 'xdg=' "$PROJECT_ROOT/overlays/usr/local/bin/linuxbeos-theme-check"; then
  pass "themacontrole bewijst /etc/skel- en /etc/xdg-integratie"
else
  fail "themacontrole controleert /etc/skel of /etc/xdg niet"
fi
if grep -q 'skel=ok' "$PROJECT_ROOT/tests/lib/run-vm-test.sh"; then
  pass "rooktest eist de /etc/skel-integratie in de live-sessie"
else
  fail "rooktest controleert de /etc/skel-integratie niet"
fi
if grep -q 'geen LINUXBEOS_THEME-marker' "$PROJECT_ROOT/tests/lib/run-install-test.sh" \
   && grep -q 'thema-integratie in het geïnstalleerde systeem' "$PROJECT_ROOT/tests/lib/run-install-test.sh"; then
  pass "installatietest eist thema en /etc/skel-integratie op het doel"
else
  fail "installatietest behandelt het thema op het doel niet als release-eis"
fi
if grep -q '10-build-iso.sh' "$PROJECT_ROOT/scripts/20-build-release.sh" \
   && grep -q 'release-matrix.sh' "$PROJECT_ROOT/scripts/20-build-release.sh"; then
  pass "één-commando-release bouwt de ISO en draait de releasegate"
else
  fail "scripts/20-build-release.sh mist de build of de releasegate"
fi
if grep -q 'LINUXBEOS_BTRFS_ROLLBACK ok' "$PROJECT_ROOT/tests/release-matrix.sh" \
   && grep -q 'LINUXBEOS_THEME ok' "$PROJECT_ROOT/tests/release-matrix.sh" \
   && grep -q 'geïnstalleerd systeem = live-look' "$PROJECT_ROOT/tests/release-matrix.sh"; then
  pass "releasematrix controleert thema, Btrfs-rollback en live-look"
else
  fail "releasematrix mist een van de releasecriteria"
fi
if grep -q '^release:' "$PROJECT_ROOT/Makefile" \
   && grep -q '^release-full:' "$PROJECT_ROOT/Makefile" \
   && grep -q '^matrix:' "$PROJECT_ROOT/Makefile"; then
  pass "Makefile heeft release-, release-full- en matrixdoelen"
else
  fail "Makefile mist de release- of matrixdoelen"
fi

printf '\n'
if (( FAILURES > 0 )); then
  printf '%sStatische controle mislukt: %d fout(en).%s\n' "$C_RED" "$FAILURES" "$C_RESET" >&2
  exit 1
fi
printf '%sStatische controle geslaagd.%s\n' "$C_GREEN" "$C_RESET"
