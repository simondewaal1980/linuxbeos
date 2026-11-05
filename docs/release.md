# Releaseproces

LinuxBeOS gebruikt één releasecommando en een vaste releasematrix. Een
release is pas klaar als de matrix groen is en de artefacten in `dist/`
reproduceerbaar zijn vastgelegd.

## Eén commando

```sh
# Snelle release: hostcheck -> ISO -> SHA256 -> statische controle -> rooktest
scripts/20-build-release.sh

# Volledige releasegate: plus Btrfs-installatie en rollback op UEFI en BIOS
scripts/20-build-release.sh --full
```

Dezelfde keten via `make`:

```sh
make release        # rooktest (statisch + live UEFI/BIOS)
make release-full   # volledige releasegate (inclusief Btrfs en rollback)
```

Alleen `--full` levert een volledige releasegate. Het rapport van `make
release` vermeldt daarom expliciet dat het om een rooktest gaat.

Nuttige varianten:

```sh
scripts/20-build-release.sh --skip-build     # bestaande dist-ISO opnieuw testen
scripts/20-build-release.sh --skip-smoke     # alleen statische controle
scripts/20-build-release.sh --keep           # testartefacten bewaren
tests/release-matrix.sh                      # matrix op de bestaande ISO
tests/release-matrix.sh --skip-install       # alleen statisch + rooktesten
```

## Schone checkout

De releaseketen werkt ook vanuit een schone kopie zonder `.git`, `.build`,
`dist` of `tests/vm`. Wijs de artefactpaden naar een bestaande build-VM en
cache, zodat de build niet alles opnieuw hoeft te downloaden:

```sh
rsync -a --exclude='.git/' --exclude='.build/' --exclude='dist/' \
  --exclude='tests/vm/*' ./ /pad/naar/schone-checkout/

cd /pad/naar/schone-checkout
LINUXBEOS_BUILD_DIR=/pad/naar/bestaande/.build \
LINUXBEOS_DIST_DIR=/pad/naar/schone-dist \
LINUXBEOS_TEST_VM_DIR=/pad/naar/schone-tests \
  scripts/20-build-release.sh --full
```

Gebruik hiervoor een pad op een bestandssysteem met voldoende ruimte; `/tmp`
is op sommige hosts een kleine tmpfs.

## Wat het releasecommando doet

1. `scripts/00-check-host.sh` controleert QEMU/KVM, OVMF, netwerk,
   schijfruimte en de statische projectconfiguratie.
2. `scripts/10-build-iso.sh` bouwt de ISO in de geïsoleerde Debian Sid
   build-VM en haalt hem op naar `dist/`.
3. Het script controleert `SHA256SUMS` en schrijft `release-info.txt`.
4. `tests/release-matrix.sh` draait de statische controle en de
   UEFI/BIOS-rooktesten. Met `--full` volgt ook de volledige
   Btrfs-installatiematrix.
5. Het resultaat staat in `dist/release-matrix.txt`; bij een fout stopt het
   script met een niet-nul exitcode.

## ISO-naamgeving

De ISO-naam staat centraal in `config/project.conf`:

```
${DISTRO_SLUG}-${DISTRO_VERSION}-${DEBIAN_ARCH}.iso
```

Voor versie 0.1 levert dat:

```
dist/linuxbeos-0.1-amd64.iso
```

Wijzig de naam niet handmatig; pas `DISTRO_SLUG`, `DISTRO_VERSION` of
`DEBIAN_ARCH` aan en bouw opnieuw. De ISO-volume-label staat in `ISO_VOLUME`.

## Artefacten

| Bestand | Inhoud |
|---|---|
| `dist/linuxbeos-<versie>-amd64.iso` | de hybride UEFI/BIOS-ISO |
| `dist/SHA256SUMS` | checksum in `sha256sum -c`-formaat |
| `dist/build-info.txt` | distro, suite, kernel, live-build-versie, bouwtijd |
| `dist/release-info.txt` | versie, ISO, SHA256, grootte, matrixstatus |
| `dist/release-matrix.txt` | alle releasegate-controles met bewijsregels |

Controleer een gedownloade release met:

```sh
cd dist
sha256sum -c SHA256SUMS
```

## Releasematrix

`tests/release-matrix.sh` controleert:

| Onderdeel | UEFI | BIOS |
|---|---|---|
| Statische projectcontrole | — | — |
| Live-sessie + netwerk | ✓ | ✓ |
| Thema in de live-sessie (`deskbar=top-right`) | ✓ | ✓ |
| Thema via `/etc/skel` en `/etc/xdg` | ✓ | ✓ |
| Donkere GTK-variant aanwezig (`dark=ok`) | ✓ | ✓ |
| Btrfs-installatie | ✓ | ✓ |
| Zelfstandige boot van het doel | ✓ | ✓ |
| Thema op het geïnstalleerde systeem | ✓ | ✓ |
| Snapshot maken en GRUB-entry | ✓ | ✓ |
| Boot vanaf de snapshot | ✓ | ✓ |
| Rollback met behoud van `/home` | ✓ | ✓ |
| Geïnstalleerd systeem = live-look | ✓ | ✓ |

De matrix schrijft per controle een regel met de gevonden marker. Ontbreekt
een marker, dan faalt de release. Gebruik `--keep` om de qcow2-schijven,
seriële logboeken en screenshots onder `tests/vm/` te bewaren.

## Versietag

Na een groene `make release-full`:

```sh
git tag -a v0.1 -m "LinuxBeOS 0.1"
git push origin main --tags
```

De tag hoort bij de commit waarmee de ISO is gebouwd. Noteer in de
release-aankondiging:

- versienummer en datum;
- SHA256 uit `dist/SHA256SUMS`;
- link naar `dist/release-matrix.txt`;
- eventuele bekende beperkingen uit [calamares.md](calamares.md),
  [btrfs-layout.md](btrfs-layout.md) en [theme.md](theme.md).

## Rollback van een release

Is een release toch niet goed, verwijder dan de tag en publiceer geen nieuwe
artefacten onder hetzelfde versienummer:

```sh
git tag -d v0.1
git push origin :refs/tags/v0.1
```

Verhoog `DISTRO_VERSION` in `config/project.conf` en bouw opnieuw. Bewaar de
oude ISO alleen als die expliciet als terugvaloptie is gecommuniceerd.
