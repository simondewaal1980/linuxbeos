# LinuxBeOS

Een Linux-distributie met een BeOS 5-geïnspireerde desktop, gebouwd op
Debian Sid. Dit is de werknaam; de definitieve naam kan later via
`config/project.conf` worden gewijzigd.

> **Status:** fase 0, 1, 2, 3 en 4 zijn gereed. De ISO installeert via
> Calamares op Btrfs met subvolumes, Snapper-snapshots en een GRUB-menu met
> snapshots. De live-sessie én het geïnstalleerde systeem starten
> out-of-the-box met het BeOS 5-thema: gele titeltab, lichte en donkere
> GTK-variant, Deskbar rechtsboven, eigen iconen, cursor en achtergrond.
> Nieuwe gebruikers krijgen
> dezelfde look via `/etc/skel` en de xfconf-standaardwaarden.
> Eén commando bouwt en test de release; de volledige matrix bewijst
> UEFI/BIOS × Btrfs-installatie × thema × snapshot/rollback.
> Zie [docs/development-progress.md](docs/development-progress.md),
> [docs/installation.md](docs/installation.md) en
> [docs/release.md](docs/release.md).

## Uitgangspunten

- Debian Sid (unstable), amd64, systemd
- XFCE met een eigen BeOS 5-thema (xfwm4, GTK2/GTK3, Deskbar, iconen)
- Calamares 3.4.x als grafische installer
- Btrfs met subvolumes, zstd-compressie, Snapper en een GRUB-snapshotmenu
- GRUB, zowel UEFI als BIOS
- ISO's worden gebouwd in een geïsoleerde Debian Sid VM met `live-build`

De host is alleen verantwoordelijk voor QEMU/KVM, netwerk en het ophalen van
de ISO. Zo blijven de build-afhankelijkheden weg van de host.

## Snelstart

Vereist: Linux met KVM, QEMU, OVMF, `xorriso`, `curl`, `rsync` en `ssh`.
De gebruiker moet `/dev/kvm` kunnen openen (kvm-groep of ACL).

Eén commando bouwt en test de complete release:

```sh
make release        # hostcheck -> ISO -> statische controle -> UEFI/BIOS-rooktest
make release-full   # plus Btrfs-installatie, thema en rollback op UEFI en BIOS
```

Of met de scripts rechtstreeks:

```sh
# 1. Controleer de host en de projectconfiguratie
scripts/00-check-host.sh

# 2. Maak en start de Debian Sid build-VM (eenmalig; daarna hergebruikt)
scripts/01-create-build-vm.sh

# 3. Bouw de ISO en draai automatisch de rooktesten
scripts/20-build-release.sh

# 4. Optioneel: de volledige releasematrix op de bestaande ISO
tests/release-matrix.sh

# 5. Handmatige deelstappen blijven beschikbaar
scripts/10-build-iso.sh
tests/test-uefi.sh
tests/test-bios.sh
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
- Een GTK2/GTK3-thema met BeOS-grijstinten, vlakke widgets en rechte randen,
  plus de donkere variant `LinuxBeOS-Dark` die via Instellingen → Vormgeving
  of `linuxbeos-theme-mode` te kiezen is
- Een Deskbar rechtsboven: applicatiemenu met eigen logo, vensterlijst en klok
- Een eigen SVG-icoonthema, Xcursor-thema en LinuxBeOS-achtergrond
- LightDM-greeter, terminalprofiel en Liberation-lettertypen als open
  alternatief voor de BeOS-systeemfont
- ZSH als standaardshell met een tweeregelige BeOS-gekleurde prompt,
  distro-branding, git-herkenning via `vcs_info` (branch plus
  staged/unstaged wijzigingen), exitstatus, looptijd van trage commando's,
  achtergrondtaken en een bescheiden klok
- `git`, de `opencode`-CLI (vastgepinde versie met SHA256-controle) en Google
  Chrome stable uit de officiële Google-repository, naast Firefox ESR
- Een automatische themacontrole die `LINUXBEOS_THEME ok ...` naar de seriële
  console schrijft; de rooktesten op UEFI en BIOS vereisen deze marker
- Een statische controle van alle themabestanden, symlinks en xfconf-waarden

Zie [docs/theme.md](docs/theme.md) voor het ontwerp, de bekende beperkingen,
de licenties en de visuele checklist.

## Wat fase 4 toevoegt

- Calamares-branding in de BeOS-stijl: grijs/geel palet, bijgewerkt logo en
  een slideshow met de pijlers van de distributie (open source, Debian Sid,
  Btrfs-snapshots, BeOS 5-look)
- Thema-integratie op het doelsysteem via `/etc/xdg` én `/etc/skel`, zodat
  elke nieuwe gebruiker de Deskbar en het volledige thema krijgt
- `scripts/20-build-release.sh`: één commando voor hostcheck → ISO → SHA256
  → automatische rooktest; `--full` draait ook de installatiematrix
- `tests/release-matrix.sh`: releasegate met UEFI/BIOS × Btrfs-installatie ×
  thema op het doel × snapshot-boot × rollback × behoud van `/home`
- Releaserapport in `dist/release-matrix.txt` en metadata in
  `dist/release-info.txt`
- Installatiehandleiding en releaseproces in
  [docs/installation.md](docs/installation.md) en
  [docs/release.md](docs/release.md)

## Repository-indeling

```
config/project.conf       centrale naam, versie, mirror, VM-instellingen
build/live-build/         live-build auto/config, pakketlijsten, hooks, includes
overlays/                 xfconf-standaarden, /etc/skel, LightDM en themascripts
desktop/                  xfwm4-, GTK-, icoon- en cursorassets
installer/calamares/      installer-configuratie en BeOS-branding
btrfs/                    subvolumes, Snapper, GRUB-snapshots en rollback
scripts/                  hostcontrole, build-VM, ISO-bouw en releasecommando
tests/                    statische tests, QEMU-tests en releasematrix
docs/                     architectuur, build-, installatie- en releasedocumentatie
```

## Documentatie

- [Voortgang en beslissingen](docs/development-progress.md)
- [Installatiehandleiding](docs/installation.md)
- [Calamares-installer](docs/calamares.md)
- [Architectuur](docs/architecture.md)
- [Buildhandleiding](docs/build-guide.md)
- [Releaseproces](docs/release.md)
- [Probleemoplossing](docs/troubleshooting.md)
- [Btrfs-layout en rollback](docs/btrfs-layout.md)
- [BeOS-thema](docs/theme.md)
