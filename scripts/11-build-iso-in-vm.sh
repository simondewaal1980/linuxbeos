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
chmod +x "$WORKDIR/config/includes.chroot/usr/local/bin/linuxbeos-session-ready" 2>/dev/null || true

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
