# LinuxBeOS

Een Linux-distributie met een BeOS 5-geïnspireerde desktop, gebouwd op
Debian Sid. Dit is de werknaam; de definitieve naam kan later via
`config/project.conf` worden gewijzigd.

> **Status:** fase 0, 1, 2 en 3 zijn gereed. De ISO installeert via Calamares op
> Btrfs met subvolumes, Snapper-snapshots en een GRUB-menu met snapshots.
> De live-sessie start out-of-the-box met het BeOS 5-thema: gele titeltab,
> GTK-thema, deskbar rechtsboven, eigen iconen, cursor en achtergrond. Het
> geïnstalleerde systeem neemt dezelfde look over.
> De geautomatiseerde tests bewijzen snapshot-boot en rollback op UEFI én BIOS
> en controleren het thema via een seriële marker, ook op het doelsysteem.
> Zie [docs/development-progress.md](docs/development-progress.md),
> [docs/btrfs-layout.md](docs/btrfs-layout.md) en
> [docs/theme.md](docs/theme.md). Volgende stap: fase 4 (volledige integratie).

## Uitgangspunten

- Debian Sid (unstable), amd64, systemd
- XFCE als desktop; later een BeOS 5-thema (fase 3)
- Calamares 3.4.x als installer (fase 1)
- Btrfs met subvolumes, zstd-compressie, Snapper en grub-btrfs (fase 2)
- GRUB, zowel UEFI als BIOS
- ISO's worden gebouwd in een geïsoleerde Debian Sid VM met `live-build`

De host is alleen verantwoordelijk voor QEMU/KVM, netwerk en het ophalen van
de ISO. Zo blijven de build-afhankelijkheden weg van de host.

## Snelstart

Vereist: Linux met KVM, QEMU, OVMF, `xorriso`, `curl`, `rsync` en `ssh`.
De gebruiker moet `/dev/kvm` kunnen openen (kvm-groep of ACL).

```sh
# 1. Controleer de host en de projectconfiguratie
scripts/00-check-host.sh

# 2. Maak en start de Debian Sid build-VM (eenmalig; daarna hergebruikt)
scripts/01-create-build-vm.sh

# 3. Bouw de ISO; het resultaat staat in dist/
scripts/10-build-iso.sh

# 4. Rooktesten: UEFI (OVMF) en BIOS (SeaBIOS)
tests/test-uefi.sh
tests/test-bios.sh

# 5. Installatietests: Btrfs-installatie + snapshot/rollback op het doel
tests/test-install-uefi.sh
tests/test-install-bios.sh
```

De build-VM is bereikbaar op `127.0.0.1:2222` (SSH-sleutel in
`.build/vm/id_ed25519`). Beheer:

```sh
scripts/01-create-build-vm.sh --status
scripts/01-create-build-vm.sh --log
scripts/01-create-build-vm.sh --stop
scripts/01-create-build-vm.sh --recreate   # schone VM, basisimage blijft
scripts/01-create-build-vm.sh --delete     # VM verwijderen
```

## Wat fase 0 oplevert

- Een reproduceerbare live-build-pipeline voor Debian Sid/amd64
- Een hybride ISO die zowel via UEFI als BIOS boot
- Een live-sessie met LightDM-autologin en een minimale XFCE-desktop
- NetworkManager met automatische DHCP en een werkende browser (Firefox ESR)
- PipeWire voor audio
- Geautomatiseerde rooktesten die via de seriële console controleren of de
  Xfce-sessie en het netwerk daadwerkelijk gereed zijn

Nog niet in fase 0: Calamares, Btrfs, Snapper en het BeOS-thema.

## Wat fase 1 toevoegt

- Calamares 3.4.x in de live-sessie, startbaar vanaf het bureaublad en uit
  het menu
- Een neutrale LinuxBeOS-branding met eigen logo en slideshow
- De standaard keten partition → mount → unpackfs → fstab → locale →
  keyboard → users → bootloader → umount
- Installatie op ext4 in fase 1 (de keten werd eerst los van Btrfs
  gevalideerd); sinds fase 2 is Btrfs de standaard
- Verwijdering van Calamares en de live-pakketten uit het doelsysteem
- Een geautomatiseerde acceptatietest die installeert en daarna het
  geïnstalleerde systeem zelfstandig laat booten

Zie [docs/calamares.md](docs/calamares.md) voor de moduleketen en de
testaanpak.

## Wat fase 2 toevoegt

- Btrfs als standaardbestandssysteem met subvolumes `@`, `@home`,
  `@snapshots`, `@var_log`, `@var_cache` en `@swap`
- `compress=zstd` en `noatime` op de systeem-subvolumes
- Snapper met tijdlijn-snapshots, apt-hook en opruimbeleid
- Een GRUB-menu met read-only snapshot-entries (eigen grub-btrfs-equivalent,
  omdat Debian Sid geen grub-btrfs-pakket heeft)
- `linuxbeos-rollback` om `/` terug te zetten zonder `/home` te verliezen
- Een geautomatiseerde test die snapshot maken, snapshot-boot, rollback en
  behoud van `/home` op UEFI én BIOS bewijst

Zie [docs/btrfs-layout.md](docs/btrfs-layout.md) voor de indeling, de
Snapper-configuratie en de rollbackprocedure.

## Wat fase 3 toevoegt

- Een eigen xfwm4-thema met de kenmerkende gele BeOS-titeltab, sluitknop links
  en zoomknop rechts
- Een GTK2/GTK3-thema met BeOS-grijstinten, vlakke widgets en rechte randen
- Een Deskbar rechtsboven: applicatiemenu met eigen logo, vensterlijst en klok
- Een eigen SVG-icoonthema, Xcursor-thema en LinuxBeOS-achtergrond
- LightDM-greeter, terminalprofiel en Liberation-lettertypen als open
  alternatief voor de BeOS-systeemfont
- Een automatische themacontrole die `LINUXBEOS_THEME ok ...` naar de seriële
  console schrijft; de rooktesten op UEFI en BIOS vereisen deze marker
- Een statische controle van alle themabestanden, symlinks en xfconf-waarden

Zie [docs/theme.md](docs/theme.md) voor het ontwerp, de bekende beperkingen,
de licenties en de visuele checklist.

## Repository-indeling

```
config/project.conf       centrale naam, versie, mirror, VM-instellingen
build/live-build/         live-build auto/config, pakketlijsten, hooks, includes
overlays/                 xfconf-standaardwaarden, LightDM en themascripts (fase 3)
desktop/                  xfwm4-, GTK-, icoon- en cursorassets (fase 3)
installer/calamares/      installer-configuratie (fase 1)
btrfs/                    subvolumes, Snapper, GRUB-snapshots en rollback (fase 2)
scripts/                  hostcontrole, build-VM, ISO-bouw
tests/                    statische tests en QEMU-rooktesten
docs/                     architectuur, buildhandleiding, voortgang
```

## Documentatie

- [Voortgang en beslissingen](docs/development-progress.md)
- [Calamares-installer (fase 1)](docs/calamares.md)
- [Architectuur](docs/architecture.md)
- [Buildhandleiding](docs/build-guide.md)
- [Probleemoplossing](docs/troubleshooting.md)
- [Btrfs-layout (fase 2)](docs/btrfs-layout.md)
- [BeOS-thema (fase 3)](docs/theme.md)
