# LinuxBeOS

Een Linux-distributie met een BeOS 5-geïnspireerde desktop, gebouwd op
Debian Sid. Dit is de werknaam; de definitieve naam kan later via
`config/project.conf` worden gewijzigd.

> **Status:** fase 0 is gereed. De ISO boot in UEFI én BIOS tot een werkende
> XFCE-desktop met netwerk. Zie
> [docs/development-progress.md](docs/development-progress.md).
> Volgende stap: fase 1 (Calamares).

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

## Repository-indeling

```
config/project.conf       centrale naam, versie, mirror, VM-instellingen
build/live-build/         live-build auto/config, pakketlijsten, hooks, includes
overlays/                 bestanden over het live-systeem (latere fasen)
desktop/                  thema-assets (fase 3)
installer/calamares/      installer-configuratie (fase 1)
btrfs/                    subvolume- en Snapper-configuratie (fase 2)
scripts/                  hostcontrole, build-VM, ISO-bouw
tests/                    statische tests en QEMU-rooktesten
docs/                     architectuur, buildhandleiding, voortgang
```

## Documentatie

- [Voortgang en beslissingen](docs/development-progress.md)
- [Architectuur](docs/architecture.md)
- [Buildhandleiding](docs/build-guide.md)
- [Probleemoplossing](docs/troubleshooting.md)
- [Btrfs-layout (fase 2)](docs/btrfs-layout.md)
