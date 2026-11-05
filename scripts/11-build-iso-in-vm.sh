#!/usr/bin/env bash
# Bouwt de ISO *binnen* de Debian Sid build-VM.
#
# Wordt normaal gesproken via SSH door scripts/10-build-iso.sh aangeroepen.
# Kan op een Debian Sid-machine ook lokaal worden gebruikt:
#   sudo scripts/11-build-iso-in-vm.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

if [[ ${EUID} -ne 0 ]]; then
  if have_cmd sudo; then
    exec sudo -- env LINUXBEOS_WORKDIR="${LINUXBEOS_WORKDIR:-}" bash "$0" "$@"
  fi
  die "dit script moet als root worden uitgevoerd"
fi

KEEP_WORKDIR=0
WORKDIR="${LINUXBEOS_WORKDIR:-}"

usage() {
  cat <<EOF
Gebruik: $0 [--workdir DIR] [--keep-workdir]

Bouwt de live-ISO met live-build. Verwacht een schone Debian Sid-omgeving
met live-build, debootstrap, squashfs-tools, xorriso en GRUB-pakketten.

  --workdir DIR    Bouwmap (standaard: \$LINUXBEOS_WORKDIR of <repo>/.build/iso)
  --keep-workdir   Bewaar de bestaande bouwmap (cache blijft behouden)
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --workdir)
      [[ $# -ge 2 ]] || die "--workdir vereist een pad"
      WORKDIR="$2"; shift
      ;;
    --keep-workdir) KEEP_WORKDIR=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "onbekende optie: $1" ;;
  esac
  shift
done

if [[ -z "$WORKDIR" ]]; then
  if [[ "$PROJECT_ROOT" == /home/*/* ]]; then
    HOME_USER="$(printf '%s' "$PROJECT_ROOT" | cut -d/ -f3)"
    WORKDIR="/home/${HOME_USER}/${DISTRO_SLUG}-build"
  else
    WORKDIR="$PROJECT_ROOT/.build/iso"
  fi
fi

require_cmd lb debootstrap mksquashfs xorriso
[[ -x "$PROJECT_ROOT/build/live-build/auto/config" ]] \
  || die "auto/config ontbreekt of is niet uitvoerbaar"

step "Live-build voorbereiden"
log "project:  $PROJECT_ROOT"
log "bouwmap:  $WORKDIR"

# Behoud de live-build pakketcache tussen builds, maar bouw de rest schoon.
CACHE_BACKUP="${WORKDIR}.cache"
if [[ -d "$WORKDIR/cache" ]]; then
  rm -rf "$CACHE_BACKUP"
  mv "$WORKDIR/cache" "$CACHE_BACKUP"
fi
if (( KEEP_WORKDIR )); then
  mkdir -p "$WORKDIR"
  ( cd "$WORKDIR" && lb clean ) || true
else
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
fi
if [[ -d "$CACHE_BACKUP" ]]; then
  mv "$CACHE_BACKUP" "$WORKDIR/cache"
fi

cp "$PROJECT_ROOT/config/project.conf" "$WORKDIR/project.conf"
cp -a "$PROJECT_ROOT/build/live-build/auto" "$WORKDIR/"
cp -a "$PROJECT_ROOT/build/live-build/config" "$WORKDIR/"
chmod +x "$WORKDIR/auto/config"
if [[ -d "$WORKDIR/config/hooks/live" ]]; then
  find "$WORKDIR/config/hooks/live" -type f -exec chmod +x {} +
fi

step "Calamares-configuratie klaarzetten"
# De installer-configuratie staat één keer in installer/calamares en wordt
# hier in de live-build-includes geplaatst. Zo blijft er één bron van
# waarheid en kan een schone checkout altijd dezelfde ISO bouwen.
CALAMARES_SRC="$PROJECT_ROOT/installer/calamares"
CALAMARES_DEST="$WORKDIR/config/includes.chroot/etc/calamares"
CALAMARES_AUTO_DEST="$WORKDIR/config/includes.chroot/etc/calamares-auto"
[[ -f "$CALAMARES_SRC/settings.conf" ]] || die "installer/calamares/settings.conf ontbreekt"

rm -rf "$CALAMARES_DEST" "$CALAMARES_AUTO_DEST"
mkdir -p "$CALAMARES_DEST" "$CALAMARES_AUTO_DEST"
cp -a "$CALAMARES_SRC/." "$CALAMARES_DEST/"
# De testvariant hoort niet als submap in de productieconfiguratie.
rm -rf "$CALAMARES_DEST/auto"
cp -a "$CALAMARES_DEST/." "$CALAMARES_AUTO_DEST/"
cp -a "$CALAMARES_SRC/auto/." "$CALAMARES_AUTO_DEST/"

# Live-hulpjes en launchers moeten uitvoerbaar zijn.
find "$WORKDIR/config/includes.chroot/usr/local/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
find "$WORKDIR/config/includes.chroot/etc/skel/Desktop" -type f -name '*.desktop' -exec chmod 0755 {} + 2>/dev/null || true

step "Btrfs-, Snapper- en rollbackconfiguratie klaarzetten"
# De Btrfs-bestanden staan één keer in btrfs/ en worden hier in de
# live-build-includes geplaatst. Ze komen daarmee zowel in de live-sessie als
# via unpackfs in het doelsysteem terecht.
BTRFS_SRC="$PROJECT_ROOT/btrfs"
INCLUDES="$WORKDIR/config/includes.chroot"
[[ -d "$BTRFS_SRC" ]] || die "btrfs/ ontbreekt"

install -D -m 0644 "$BTRFS_SRC/snapper/root" \
  "$INCLUDES/etc/snapper/configs/${SNAPPER_CONFIG}"
install -D -m 0644 "$BTRFS_SRC/snapper/default" "$INCLUDES/etc/default/snapper"
install -D -m 0755 "$BTRFS_SRC/grub.d/41_snapshots-btrfs" \
  "$INCLUDES/etc/grub.d/41_snapshots-btrfs"
for script in linuxbeos-rollback linuxbeos-update-grub linuxbeos-btrfs-test; do
  install -D -m 0755 "$BTRFS_SRC/bin/$script" "$INCLUDES/usr/local/bin/$script"
done
for unit in grub-btrfs.service grub-btrfs.path linuxbeos-btrfs-test.service; do
  install -D -m 0644 "$BTRFS_SRC/systemd/$unit" "$INCLUDES/etc/systemd/system/$unit"
done

# Draai de snapshot-/rollbackscripts ook als root via sbin beschikbaar.
mkdir -p "$INCLUDES/usr/local/sbin"
for script in linuxbeos-rollback linuxbeos-update-grub; do
  ln -sfn "../bin/$script" "$INCLUDES/usr/local/sbin/$script"
done

# Eén centrale runtimeconfiguratie, gegenereerd uit config/project.conf.
install -d -m 0755 "$INCLUDES/etc/linuxbeos"
{
  printf '# Gegenereerd uit config/project.conf tijdens de build.\n'
  printf 'BTRFS_ROOT_SUBVOL="/%s"\n' "${BTRFS_ROOT_SUBVOL#/}"
  printf 'BTRFS_HOME_SUBVOL="/%s"\n' "${BTRFS_HOME_SUBVOL#/}"
  printf 'BTRFS_SNAPSHOTS_SUBVOL="/%s"\n' "${BTRFS_SNAPSHOTS_SUBVOL#/}"
  printf 'BTRFS_VAR_LOG_SUBVOL="/%s"\n' "${BTRFS_VAR_LOG_SUBVOL#/}"
  printf 'BTRFS_VAR_CACHE_SUBVOL="/%s"\n' "${BTRFS_VAR_CACHE_SUBVOL#/}"
  printf 'BTRFS_SWAP_SUBVOL="/%s"\n' "${BTRFS_SWAP_SUBVOL#/}"
  printf 'BTRFS_SUBVOLUMES="%s"\n' "$BTRFS_SUBVOLUMES"
  printf 'BTRFS_SNAPSHOTS_MOUNT="%s"\n' "$BTRFS_SNAPSHOTS_MOUNT"
  printf 'BTRFS_COMPRESS="%s"\n' "$BTRFS_COMPRESS"
  printf 'BTRFS_MOUNT_OPTIONS="%s"\n' "$BTRFS_MOUNT_OPTIONS"
  printf 'SNAPPER_CONFIG="%s"\n' "$SNAPPER_CONFIG"
} > "$INCLUDES/etc/linuxbeos/btrfs.conf"
chmod 0644 "$INCLUDES/etc/linuxbeos/btrfs.conf"

step "Shell- en software-identiteit klaarzetten"
# De ZSH-prompt leest de distronaam/versie uit identity.conf. De chroot-hook
# 0400-apps.chroot leest software.conf voor de vastgepinde opencode-versie.
install -d -m 0755 "$INCLUDES/etc/linuxbeos"
{
  printf 'LINUXBEOS_NAME="%s"\n' "$DISTRO_NAME"
  printf 'LINUXBEOS_VERSION="%s"\n' "$DISTRO_VERSION"
  printf 'LINUXBEOS_TAGLINE="%s"\n' "$DISTRO_TAGLINE"
} > "$INCLUDES/etc/linuxbeos/identity.conf"
chmod 0644 "$INCLUDES/etc/linuxbeos/identity.conf"
{
  printf 'OPENCODE_VERSION="%s"\n' "$OPENCODE_VERSION"
  printf 'OPENCODE_SHA256_AMD64="%s"\n' "$OPENCODE_SHA256_AMD64"
  printf 'OPENCODE_URL_AMD64="%s"\n' "$OPENCODE_URL_AMD64"
  printf 'GOOGLE_CHROME_CHANNEL="%s"\n' "$GOOGLE_CHROME_CHANNEL"
  printf 'GOOGLE_CHROME_REPO="%s"\n' "$GOOGLE_CHROME_REPO"
} > "$INCLUDES/etc/linuxbeos/software.conf"
chmod 0644 "$INCLUDES/etc/linuxbeos/software.conf"

step "BeOS-thema en desktopconfiguratie klaarzetten"
# De thema-assets staan één keer in desktop/ en de xfconf-standaardwaarden in
# overlays/. Beide worden hier in de live-build-includes geplaatst, zodat de
# live-sessie en (via unpackfs) het doelsysteem dezelfde look krijgen.
DESKTOP_SRC="$PROJECT_ROOT/desktop"
OVERLAYS_SRC="$PROJECT_ROOT/overlays"
[[ -f "$DESKTOP_SRC/xfwm4/themerc" ]] || die "desktop/xfwm4/themerc ontbreekt"
[[ -f "$DESKTOP_SRC/gtk/dark/gtk-3.0/gtk.css" ]] || die "donker GTK-thema ontbreekt"
[[ -d "$OVERLAYS_SRC/etc/xdg" ]] || die "overlays/etc/xdg ontbreekt"

THEME_DEST="$INCLUDES/usr/share/themes/LinuxBeOS"
THEME_DARK_DEST="$INCLUDES/usr/share/themes/LinuxBeOS-Dark"
ICON_DEST="$INCLUDES/usr/share/icons/LinuxBeOS"
BACKGROUND_DEST="$INCLUDES/usr/share/backgrounds/linuxbeos"

rm -rf "$THEME_DEST" "$THEME_DARK_DEST" "$ICON_DEST" "$BACKGROUND_DEST"
install -d -m 0755 "$THEME_DEST" "$THEME_DARK_DEST" "$ICON_DEST" "$BACKGROUND_DEST"

# xfwm4-thema (PNG + XPM-fallback) en GTK2/GTK3-thema in één themamap.
cp -a "$DESKTOP_SRC/xfwm4" "$THEME_DEST/xfwm4"
cp -a "$DESKTOP_SRC/gtk/gtk-2.0" "$THEME_DEST/gtk-2.0"
cp -a "$DESKTOP_SRC/gtk/gtk-3.0" "$THEME_DEST/gtk-3.0"
install -m 0644 "$DESKTOP_SRC/gtk/index.theme" "$THEME_DEST/index.theme"

# Donkere GTK-variant. Het vensterdecoratie- en icoonthema blijven gelijk;
# alleen de GTK-kleuren verschillen, zodat de gele BeOS-tab herkenbaar blijft.
cp -a "$DESKTOP_SRC/gtk/dark/gtk-2.0" "$THEME_DARK_DEST/gtk-2.0"
cp -a "$DESKTOP_SRC/gtk/dark/gtk-3.0" "$THEME_DARK_DEST/gtk-3.0"
install -m 0644 "$DESKTOP_SRC/gtk/dark/index.theme" "$THEME_DARK_DEST/index.theme"

# Iconen en cursors delen dezelfde XDG-iconmap.
cp -a "$DESKTOP_SRC/icons/LinuxBeOS/." "$ICON_DEST/"
cp -a "$DESKTOP_SRC/cursors/LinuxBeOS/." "$ICON_DEST/"

install -m 0644 "$DESKTOP_SRC/backgrounds/linuxbeos-wallpaper.png" \
  "$BACKGROUND_DEST/linuxbeos-wallpaper.png"
install -m 0644 "$DESKTOP_SRC/backgrounds/linuxbeos-greeter.png" \
  "$BACKGROUND_DEST/linuxbeos-greeter.png"

# Licentie en herkomstdocumentatie mee in de ISO.
install -d -m 0755 "$INCLUDES/usr/share/doc/linuxbeos-theme"
install -m 0644 "$DESKTOP_SRC/LICENSE" "$INCLUDES/usr/share/doc/linuxbeos-theme/LICENSE"
install -m 0644 "$DESKTOP_SRC/NOTICE.md" "$INCLUDES/usr/share/doc/linuxbeos-theme/NOTICE.md"

# xfconf-standaardwaarden, LightDM-greeter en thema-controlescripts.
cp -a "$OVERLAYS_SRC/." "$INCLUDES/"
find "$INCLUDES/usr/local/bin" -type f -exec chmod 0755 {} + 2>/dev/null || true
find "$INCLUDES/etc/xdg/autostart" -type f -name '*.desktop' -exec chmod 0644 {} + 2>/dev/null || true
chmod 0644 "$INCLUDES/etc/skel/.zshrc" "$INCLUDES/etc/zsh/linuxbeos.zsh" 2>/dev/null || true

# Fase 4: nieuwe gebruikers krijgen de LinuxBeOS-look ook als user-level
# Xfconf-configuratie via /etc/skel. De systeemwaarden onder /etc/xdg blijven
# de bron van waarheid; deze kopie zorgt ervoor dat de panelindeling, het
# vensterdecoratie- en het icoonthema ook voor een later aangemaakte
# gebruiker direct kloppen. Calamares' users-module kopieert /etc/skel naar
# de nieuwe home, waardoor het geïnstalleerde systeem dezelfde look heeft.
SKEL_XFCE="$INCLUDES/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"
install -d -m 0755 "$SKEL_XFCE"
for xml in "$INCLUDES"/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/*.xml; do
  [[ -f "$xml" ]] || continue
  install -m 0644 "$xml" "$SKEL_XFCE/$(basename "$xml")"
done
find "$INCLUDES/etc/skel/.config" -type d -exec chmod 0755 {} + 2>/dev/null || true
find "$INCLUDES/etc/skel/.config" -type f -exec chmod 0644 {} + 2>/dev/null || true

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

step "ISO bouwen met live-build"
log "dit kan lang duren (debootstrap + pakketten + squashfs + ISO)"
cd "$WORKDIR"

set +e
lb build 2>&1 | tee "$WORKDIR/lb-build.log"
status=${PIPESTATUS[0]}
set -e
if (( status != 0 )); then
  die "lb build mislukte (exit $status); zie $WORKDIR/lb-build.log"
fi

ISO="$WORKDIR/live-image-${DEBIAN_ARCH}.hybrid.iso"
[[ -f "$ISO" ]] || die "ISO niet gevonden op $ISO"

KERNEL_VERSION="$(ls "$WORKDIR"/chroot/boot/vmlinuz-* 2>/dev/null | head -1 | sed 's|.*/vmlinuz-||' || true)"
LB_VERSION="$(lb --version 2>/dev/null || echo onbekend)"
SHA256="$(sha256_of "$ISO")"
SIZE="$(du -h "$ISO" | awk '{print $1}')"

cat > "$WORKDIR/build-info.txt" <<EOF
LinuxBeOS build-info
====================
distro:        $DISTRO_NAME $DISTRO_VERSION
suite:         $DEBIAN_SUITE
architectuur:  $DEBIAN_ARCH
kernel:        ${KERNEL_VERSION:-onbekend}
live-build:    $LB_VERSION
gebouwd:       $(date -u +%Y-%m-%dT%H:%M:%SZ)
ISO:           $(basename "$ISO")
grootte:       $SIZE
sha256:        $SHA256
EOF

step "Resultaat"
ok "ISO:    $ISO"
ok "grootte: $SIZE"
ok "sha256: $SHA256"
printf '\nLINUXBEOS_ISO=%s\nLINUXBEOS_SHA256=%s\n' "$ISO" "$SHA256"
