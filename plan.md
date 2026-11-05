# LinuxBeOS — masterplan

Een Linux-distributie met een BeOS 5-geïnspireerde desktop, gebouwd op
Debian Sid (amd64, systemd). Werktitel: **LinuxBeOS**; de definitieve naam
wordt later op één plek gewijzigd via `config/project.conf`.

Dit bestand is het plan van record. De uitgebreide status, bewijzen en
beslissingen per fase staan in
[docs/development-progress.md](docs/development-progress.md).

## Uitgangspunten

- Debian Sid (unstable), amd64, systemd
- XFCE als desktopbasis; in fase 3 een BeOS 5-thema
- Calamares 3.4.x als grafische installer
- Btrfs met subvolumes, zstd-compressie, Snapper en snapshot-entries in GRUB
- GRUB als bootloader, zowel UEFI als BIOS
- ISO's worden gebouwd in een geïsoleerde Debian Sid QEMU/KVM-VM met
  `live-build`; de host levert alleen QEMU/KVM, netwerk en opslag
- Elke fase eindigt met geautomatiseerde tests en vastgelegd bewijs

## Werkwijze per fase

1. Checklist en acceptatiecriteria vooraf vastleggen.
2. Bouwen met minimale wijzigingen ten opzichte van de vorige fase.
3. Aantonen met geautomatiseerde QEMU-tests (UEFI én BIOS) plus screenshots.
4. Resultaten, buildgegevens en beslissingen vastleggen in
   `docs/development-progress.md`.

## Fase 0 — live-build-pipeline + minimale XFCE-desktop — GEREED

**Doel:** reproduceerbare ISO-bouw met een kale, werkende XFCE-desktop.
**Nog niet:** Calamares, Btrfs, BeOS-thema.

- Repo-structuur met centrale configuratie in `config/project.conf`
- Hostcontrole (`scripts/00-check-host.sh`) en build-VM
  (`scripts/01-create-build-vm.sh`)
- live-build-configuratie: Sid, amd64, GRUB UEFI+BIOS, squashfs
- Live-gebruiker met LightDM-autologin naar XFCE
- Minimale pakketlijst: Xorg, XFCE, NetworkManager, PipeWire, Firefox ESR
- Buildscripts (`scripts/10-build-iso.sh`, `scripts/11-build-iso-in-vm.sh`)
- Rooktesten `tests/test-uefi.sh` en `tests/test-bios.sh` die via de seriële
  console sessie en netwerk verifiëren
- Statische controle `tests/static/check-config.sh`

**Acceptatiecriteria (allemaal gehaald):**

- ISO boot in UEFI- én BIOS-VM tot een werkende XFCE-desktop met netwerk
- Build is herhaalbaar vanuit een schone checkout
- Resultaten en beslissingen vastgelegd

## Fase 1 — Calamares standaardinstallatie — GEREED

**Doel:** grafische installer in de live-sessie; de installatieketen eerst
los van Btrfs valideren (ext4).
**Nog niet:** Btrfs-subvolumes, snapshots, BeOS-thema.

- Calamares 3.4.x in de ISO, eigen configuratie onder `installer/calamares/`
- Neutrale branding met logo, kleuren en slideshow
- Moduleketen partition → mount → unpackfs → fstab → locale → keyboard →
  users → bootloader → umount
- Calamares en live-pakketten worden uit het doelsysteem verwijderd
- Geautomatiseerde installatietest (SMBIOS-serienummer + `/etc/calamares-auto`)
  op UEFI én BIOS, met zelfstandige boot van het geïnstalleerde systeem

**Acceptatiecriteria (allemaal gehaald):**

- Standaardinstallatie slaagt op UEFI en BIOS
- Het geïnstalleerde systeem boot zelfstandig met de aangemaakte gebruiker
- Calamares is na installatie niet meer aanwezig in het doelsysteem

## Fase 2 — Btrfs + subvolumes + snapshots — GEREED

**Doel:** Btrfs als standaard, Snapper-snapshots, GRUB-menu met snapshots en
een bewezen rollback die `/home` intact laat.
**Nog niet:** het BeOS-thema.

- Subvolumes `@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`, `@swap`
  met `compress=zstd` en `noatime`; swapfile in `@swap`
- Snapper: root-config, tijdlijn-snapshots, apt-hook, opruimbeleid
- Eigen GRUB-snapshotgenerator (`btrfs/grub.d/41_snapshots-btrfs`) omdat
  Debian Sid geen grub-btrfs-pakket heeft
- `linuxbeos-rollback` voor terugzetten van `/` met behoud van `/home`
- Driedelige geautomatiseerde test: snapshot, snapshot-boot, rollback

**Acceptatiecriteria (allemaal gehaald):**

- Installatie draait op Btrfs met de juiste subvolume-layout
- Snapshot maken en rollback werken aantoonbaar in de VM
- Snapshots zijn bootbaar vanuit het GRUB-menu
- `/home` blijft bij een rollback van `/` behouden

## Fase 3 — BeOS 5-thema op XFCE — GEREED

**Doel:** de desktop ziet er uit en voelt aan als BeOS 5.

- xfwm4-thema, GTK-thema en iconenset in BeOS 5-stijl
- Donkere GTK2/GTK3-variant `LinuxBeOS-Dark`, kiesbaar in Vormgeving en via
  `linuxbeos-theme-mode`; de Deskbar volgt de donkere paneelkleur
- Deskbar-achtige paneelinrichting (xfce4-panel)
- BeOS-cursor en -achtergronden; eigen identiteit i.p.v. Debian-live
- ZSH als standaardshell met tweeregelige BeOS-prompt: distro, git-status,
  exitcode, looptijd, achtergrondtaken en klok
- Thema-assets onder `desktop/`, geïnstalleerd via de live-build includes
- Thema actief in de live-sessie én op het geïnstalleerde systeem
- Rooktest uitgebreid met een controle op het actieve thema en de donkere
  variant (`dark=ok`)

**Acceptatiecriteria (allemaal gehaald):**

- De live-sessie toont out-of-the-box de BeOS-look (tab, GTK, Deskbar,
  iconen, cursor, achtergrond)
- De donkere GTK-variant is aanwezig en met `linuxbeos-theme-mode` wisselbaar,
  inclusief een donkere Deskbar
- De ZSH-prompt toont branding, git-status, exitcode en looptijd
- UEFI- en BIOS-rooktest schrijven `LINUXBEOS_THEME ok ...`
- Ook het geïnstalleerde systeem schrijft `LINUXBEOS_THEME ok ...`
- De visuele checklist is afgerond met screenshots in `docs/screenshots/`
- Licenties en beperkingen zijn vastgelegd in `desktop/NOTICE.md` en
  `docs/theme.md`

## Fase 4 — integratie en releasegate — TODO

**Doel:** van ontwikkelbuild naar herleidbare release.

- Eén-commando-build vanaf een schone checkout
- Volledige testmatrix (UEFI/BIOS × installatie/rollback × thema)
- Releaseproces: versiebeheer, `SHA256SUMS`, release-notes
- Aandachtspunten uit `docs/development-progress.md` afhandelen:
  definitieve distronaam, pinnen van Debian Sid (snapshot.debian.org),
  eventueel Secure Boot via `shim-signed`, opruimen van oude
  `@.broken`-roots na rollback
