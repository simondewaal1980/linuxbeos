# Ontwikkelvoortgang LinuxBeOS

Laatst bijgewerkt: 2026-11-05

## Statuswaarden

| Status | Betekenis |
|---|---|
| `TODO` | Nog niet gestart |
| `BEZIG` | In uitvoering; nog niet alle acceptatiecriteria gehaald |
| `GEBLOKKEERD` | Wacht op een beslissing, externe afhankelijkheid of bug |
| `GEREED` | Acceptatiecriteria aantoonbaar gehaald |
| `OVERGESLAGEN` | Bewust niet gedaan; reden vastgelegd |

## Fasenoverzicht

| Fase | Onderwerp | Status |
|---|---|---|
| 0 | Live-build-pipeline + minimale XFCE-desktop | GEREED |
| 1 | Calamares standaardinstallatie (ext4) | GEREED |
| 2 | Btrfs + subvolumes + snapshots | GEREED |
| 3 | BeOS 5-thema op XFCE | TODO |
| 4 | Volledige integratie en releasegate | TODO |

## Fase 0 — live-build-pipeline + minimale desktop

**Doel:** reproduceerbare ISO-bouw met een kale, werkende XFCE-desktop.
**Nog niet:** Calamares, Btrfs, BeOS-thema.

### Checklist

| # | Onderdeel | Status |
|---|---|---|
| 1 | Repo-structuur en `config/project.conf` met centrale variabelen | GEREED |
| 2 | `scripts/00-check-host.sh` (hostafhankelijkheden) | GEREED |
| 3 | `scripts/01-create-build-vm.sh` (Debian Sid KVM-build-VM) | GEREED |
| 4 | live-build-configuratie: Sid, amd64, GRUB UEFI+BIOS, squashfs | GEREED |
| 5 | Live-gebruiker met autologin (LightDM → XFCE) | GEREED |
| 6 | Minimale pakketlijst (Xorg, XFCE, NetworkManager, PipeWire, Firefox ESR) | GEREED |
| 7 | `scripts/10-build-iso.sh` + `scripts/11-build-iso-in-vm.sh` | GEREED |
| 8 | `tests/test-uefi.sh` en `tests/test-bios.sh` | GEREED |
| 9 | Statische controle `tests/static/check-config.sh` | GEREED |
| 10 | Bewijs: ISO boot in UEFI- én BIOS-VM tot XFCE + netwerk | GEREED |
| 11 | Vastleggen resultaten, screenshots en buildgegevens | GEREED |

### Acceptatiecriteria

- [x] ISO boot in een UEFI-VM tot een werkende XFCE-desktop met netwerk.
- [x] ISO boot in een BIOS-VM tot een werkende XFCE-desktop met netwerk.
- [x] De build is herhaalbaar vanuit een schone checkout.
- [x] Resultaten en beslissingen zijn in dit document vastgelegd.

### Bewijs

| Controle | Resultaat |
|---|---|
| UEFI-boot (OVMF) | `LINUXBEOS_SMOKE session=xfce network=connected` |
| BIOS-boot (SeaBIOS) | `LINUXBEOS_SMOKE session=xfce network=connected` |
| Screenshot UEFI | [phase0-uefi.png](screenshots/phase0-uefi.png) |
| Screenshot BIOS | [phase0-bios.png](screenshots/phase0-bios.png) |
| Schone checkout (`git archive HEAD`) | Build geslaagd; UEFI- en BIOS-rooktest geslaagd op de clean-build-ISO (`9e880a93…`) |

| Buildgegeven | Waarde |
|---|---|
| ISO | `dist/linuxbeos-0.1-amd64.iso` |
| Grootte | 1,4 GiB |
| SHA256 | `97147292161c6c9beb50cf7781666d4fd4cfc260bb5daf25647996ebcc55eaef` |
| Kernel | `7.2.15+deb14-amd64` |
| live-build | `1:20250814` (Debian Sid) |
| Build-VM | Debian Sid genericcloud, QEMU/KVM, 4 vCPU, 6 GiB RAM |

De rooktest controleert niet alleen dat de kernel boot, maar ook dat LightDM
automatisch inlogt, dat de XFCE-sessie draait en dat NetworkManager een
verbinding heeft. De marker wordt door
`/usr/local/bin/linuxbeos-session-ready` naar `/dev/ttyS0` geschreven.

## Fase 1 — Calamares standaardinstallatie (ext4)

**Doel:** grafische installer in de live-sessie, standaardinstallatie op ext4.
**Nog niet:** Btrfs-subvolumes, snapshots en het BeOS-thema.

### Checklist

| # | Onderdeel | Status |
|---|---|---|
| 1 | `calamares` (3.4.x) en benodigde runtime-pakketten in de ISO | GEREED |
| 2 | Eigen configuratie onder `installer/calamares/` | GEREED |
| 3 | Neutrale branding met logo, kleuren en slideshow | GEREED |
| 4 | Standaard moduleketen partition → mount → unpackfs → fstab → locale → keyboard → users → bootloader → umount | GEREED |
| 5 | Calamares en live-pakketten verwijderen uit het doelsysteem | GEREED |
| 6 | Installer startbaar vanaf bureaublad en uit het menu | GEREED |
| 7 | Geautomatiseerde installatietest op UEFI | GEREED |
| 8 | Geautomatiseerde installatietest op BIOS | GEREED |
| 9 | Zelfstandige boot van het geïnstalleerde systeem met aangemaakte gebruiker | GEREED |
| 10 | Documentatie (`docs/calamares.md`, build-guide, troubleshooting) | GEREED |

### Acceptatiecriteria

- [x] Standaardinstallatie (ext4) slaagt op UEFI.
- [x] Standaardinstallatie (ext4) slaagt op BIOS.
- [x] Het geïnstalleerde systeem boot zelfstandig met de aangemaakte gebruiker.
- [x] Calamares is na de installatie niet meer in het doelsysteem aanwezig.

### Bewijs

| Controle | UEFI | BIOS |
|---|---|---|
| Installatiemarker | `LINUXBEOS_AUTOINSTALL done` | `LINUXBEOS_AUTOINSTALL done` |
| Bootmarker doel systeem | `LINUXBEOS_INSTALLED_READY hostname=linuxbeos-standardpc` | idem |
| Xfce-sessie aangemaakte gebruiker | `LINUXBEOS_SMOKE session=xfce network=connected` | idem |
| Screenshot geïnstalleerd systeem | [phase1-installed-uefi.png](screenshots/phase1-installed-uefi.png) | [phase1-installed-bios.png](screenshots/phase1-installed-bios.png) |
| Testmap | `tests/vm/install-uefi/` | `tests/vm/install-bios/` |

| Buildgegeven | Waarde |
|---|---|
| ISO | `dist/linuxbeos-0.1-amd64.iso` |
| SHA256 | `99aafa30e4022d84ab469ac95695b3a2a711dba661bb9472510b167d680b938d` |
| Calamares | 3.4.3 (Debian Sid) |
| Bestandssysteem | ext4 |
| Doelsysteem-gebruiker | `testuser` (automatisch aangemaakt door de testconfiguratie) |

De tests draaien met een lege 20 GiB qcow2-schijf. De installatiefase duurt
enkele minuten; de daaropvolgende boot ongeveer een halve minuut. De
screenshot wordt na de sessiemarkering gemaakt, zodat het bureaublad
volledig gerenderd is.

### Aandachtspunten

- De autoinstall-test gebruikt een aparte configuratie (`/etc/calamares-auto`)
  met voorgeselecteerde partitie- en gebruikerskeuzes. De productieketen
  blijft volledig interactief.
- De testvariant wordt alleen geactiveerd door het SMBIOS-seriënnummer
  `LINUXBEOS-AUTOINSTALL`; in een normale live-sessie start hij niet.
- De installer draait als root via `sudo`; de live-gebruiker heeft daarvoor
  wachtwoordloos sudo.

## Fase 2 — Btrfs + subvolumes + snapshots

**Doel:** Btrfs als standaard, Snapper-snapshots, een GRUB-menu met
snapshots en een bewezen rollback die `/home` intact laat.
**Nog niet:** het BeOS-thema.

### Checklist

| # | Onderdeel | Status |
|---|---|---|
| 1 | Subvolume-indeling centraal in `config/project.conf` en `docs/btrfs-layout.md` | GEREED |
| 2 | Calamares `mount`/`fstab`: `@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`, `@swap`, `compress=zstd`, `noatime` | GEREED |
| 3 | Swapfile in `@swap` (zonder CoW); zram-alternatief gedocumenteerd | GEREED |
| 4 | Snapper: root-config, tijdlijn-snapshots, apt-hook, opruimregels | GEREED |
| 5 | GRUB-menu met read-only snapshot-entries (eigen grub-btrfs-equivalent) | GEREED |
| 6 | Automatische regeneratie bij boot en bij wijzigingen in `/.snapshots` | GEREED |
| 7 | `linuxbeos-rollback` met procedure voor GRUB-snapshot en live-ISO | GEREED |
| 8 | Geautomatiseerde driedelige test: snapshot, snapshot-boot, rollback | GEREED |
| 9 | Bewijs dat `/home` na de rollback behouden is | GEREED |
| 10 | Documentatie (`docs/btrfs-layout.md`, build-guide, troubleshooting) | GEREED |

### Acceptatiecriteria

- [x] Installatie draait op Btrfs met de juiste subvolumes; `btrfs subvolume list` komt overeen met de layout.
- [x] Snapper-snapshot maken en rollback werkt aantoonbaar in de VM.
- [x] Snapshots zijn bootbaar vanuit het GRUB-menu.
- [x] `/home` blijft bij een rollback van `/` behouden.

### Bewijs

| Controle | UEFI | BIOS |
|---|---|---|
| Installatiemarker | `LINUXBEOS_AUTOINSTALL done` | `LINUXBEOS_AUTOINSTALL done` |
| Btrfs-layout | `LINUXBEOS_BTRFS_LAYOUT ok subvolumes=@,@home,@snapshots,@var_log,@var_cache,@swap fstab=subvol,compress=zstd,noatime` | idem |
| Snapshot aangemaakt | `LINUXBEOS_BTRFS_SNAPSHOT ok number=2` | idem |
| Snapshot in GRUB | `LINUXBEOS_BTRFS_GRUB ok number=2` | idem |
| Boot vanaf snapshot | `LINUXBEOS_BTRFS_SNAPSHOT_BOOT ok number=2 subvol=/@snapshots/2/snapshot` | idem |
| Rollback + `/home` | `LINUXBEOS_BTRFS_ROLLBACK ok number=2 marker=original home=preserved` | idem |
| Xfce na rollback | `LINUXBEOS_SMOKE session=xfce network=connected` | idem |
| Screenshot | [phase2-installed-uefi.png](screenshots/phase2-installed-uefi.png) | [phase2-installed-bios.png](screenshots/phase2-installed-bios.png) |
| Testmap | `tests/vm/install-uefi/` | `tests/vm/install-bios/` |

| Buildgegeven | Waarde |
|---|---|
| ISO | `dist/linuxbeos-0.1-amd64.iso` |
| SHA256 | `950c19a6749aeec1dfb97132990259783a1efea779383eaa161fc3e74944be75` |
| Grootte | 1,5 GiB |
| Kernel | `7.2.15+deb14-amd64` |
| Calamares | 3.4.3 (Debian Sid) |
| Bestandssysteem | Btrfs met `compress=zstd` en `noatime` |
| Snapper | 0.10.6 (Debian Sid) |

De test doorloopt drie boots: snapshot maken en GRUB instellen, vanaf de
snapshot booten, en na de rollback controleren dat `@` terug is, de
testmarker weer `original` is en `/home/testuser/rollback-preserve` nog
bestaat. De snapshot is read-only; de rollback vervangt `@` en bewaart de
oude root als `@.broken-<tijdstip>`.

### Aandachtspunten

- Debian-Snapper ontdekt configuraties niet automatisch. `SNAPPER_CONFIGS`
  in `/etc/default/snapper` moet naar `root` wijzen; dat wordt tijdens de
  build geregeld.
- Debian Sid heeft geen `grub-btrfs`-pakket. De generator in
  `btrfs/grub.d/41_snapshots-btrfs` is een kleine eigen equivalente
  implementatie, geen third-party import.
- Snapshot-boot is read-only en de generator ondersteunt alleen een `/boot`
  die in de root-subvolume zit.
- Het swapfile is 512 MiB (Calamares-standaard) en staat in `@swap`, dat
  niet wordt gesnapshot.

## Beslissingen

| Datum | Beslissing | Reden |
|---|---|---|
| 2026-11-04 | Werktitel **LinuxBeOS** (`DISTRO_SLUG=linuxbeos`) | Gekozen door de opdrachtgever; centraal vastgelegd in `config/project.conf` |
| 2026-11-04 | Build-VM met **directe QEMU/KVM**, geen libvirt | `qemu:///system` kan niet bij de projectmap (`/home/simon` is 750); de gebruiker heeft via een ACL toegang tot `/dev/kvm`. Directe QEMU met user-networking en SSH-portforward vereist geen sudo. |
| 2026-11-04 | Build-VM op Debian Sid **genericcloud**-image + cloud-init | Reproduceerbaar, geen interactieve Debian-installer nodig; cloud-init installeert live-build en dependencies. |
| 2026-11-04 | ISO-bouw via rsync + SSH in de VM | Geen gedeelde mappen of libvirt-storage nodig; de VM blijft geïsoleerd. |
| 2026-11-04 | Rooktest via seriële console en een XFCE-autostartmarkering | Headless te draaien; controleert niet alleen boot maar ook Xfce-sessie en netwerk. |
| 2026-11-04 | Live-gebruiker `live`, hostnaam `linuxbeos` | Duidelijk en consistent met de distro-naam; later om te zetten naar de definitieve naam. |
| 2026-11-04 | Alleen `amd64` ondersteunen in fase 0 | Beperkt de testmatrix; andere architecturen zijn geen eis. |
| 2026-11-04 | Eigen GRUB-override (`config/bootloaders/grub-pc/config.cfg`) | live-build 20250814 doet `insmod efi_uga`; GRUB 2.14 in Sid levert die module niet meer. Ook een timeout toegevoegd, anders blijft het menu oneindig wachten. |
| 2026-11-04 | `network-manager-applet` i.p.v. `network-manager-gnome` | In Sid is `network-manager-gnome` een lege/verouderde pakketnaam zonder installatiekandidaat. |
| 2026-11-04 | Calamares 3.4.3 uit Debian Sid, configuratie in `installer/calamares/` | De build kopieert de configuratie naar `/etc/calamares`; één bron van waarheid voor productie en test. |
| 2026-11-04 | Fase 1 installeert alleen op **ext4**; LUKS en LVM uit | Btrfs en encryptie zijn nog niet getest; eerst de basisketen valideren. |
| 2026-11-04 | Automatische installatietest via **SMBIOS-seriënnummer** + `xdotool` | Geen kernel-cmdline-aanpassing of GUI-handelingen op de host nodig; de live-sessie start Calamares zelf met `/etc/calamares-auto`. |
| 2026-11-04 | Calamares verwijderen met de `packages`-module plus een `shellprocess`-opruimstap | Zo verdwijnen ook de live-autologin en testhulpjes uit het doelsysteem. |
| 2026-11-05 | Btrfs als standaard met subvolumes `@`, `@home`, `@snapshots`, `@var_log`, `@var_cache`, `@swap` | Subvolumes scheiden systeem, gebruikersdata en snapshots; `/home` blijft bij een rollback intact. |
| 2026-11-05 | Swapfile in `@swap` in plaats van zram | Calamares heeft ingebouwde ondersteuning (`btrfsSwapSubvol`), het is direct testbaar en `@swap` wordt niet gesnapshot. |
| 2026-11-05 | Eigen generator `41_snapshots-btrfs` in plaats van het grub-btrfs-pakket | Debian Sid levert geen `grub-btrfs`; de eigen generator is klein, licentie-vrij van third-party code en toegespitst op de LinuxBeOS-layout. |
| 2026-11-05 | `SNAPPER_CONFIGS="root"` in `/etc/default/snapper` | Debian-Snapper ontdekt configuraties niet automatisch; zonder deze regel bestaat de config voor snapperd niet. |
| 2026-11-05 | `-no-reboot` uit de installatietest verwijderd | De Btrfs-test moet drie keer binnen dezelfde QEMU-sessie kunnen herstarten; de installatiefase beëindigt QEMU via `poweroff`. |
| 2026-11-05 | Btrfs-testhulp alleen in de testvariant | De productie-opruiming verwijdert helper en dienst; de auto-cleanup laat ze staan zodat de driedelige test na de installatie kan draaien. |

## Aandachtspunten voor latere fasen

1. **Definitieve distronaam:** LinuxBeOS is een werktitel. Wijzigen op één plek
   (`config/project.conf`) en daarna ISO/branding opnieuw genereren.
2. **Pinnen van Debian Sid:** de cloud-image en pakketten zijn momenteel
   "latest". Voor strikte reproduceerbaarheid later `snapshot.debian.org`
   en een vastgepinde cloud-image-datum gebruiken.
3. **Buildtijd:** de eerste build duurt circa 15-20 minuten; latere builds
   hergebruiken de live-build-pakketcache in de VM.
4. **Live-identiteit:** het paneel toont nog de standaard Debian-live-gebruiker
   en wallpaper. Dat wordt in fase 3 vervangen door de BeOS-desktop.
5. **Secure Boot:** de ISO is nu unsigned. Voor fase 4 kan `shim-signed` +
   `grub-efi-amd64-signed` worden toegevoegd; dat is nog niet getest.
6. **Oude root opruimen:** na een rollback blijft `@.broken-<tijdstip>` staan.
   Dat is bewust (veilig terugvallen) maar moet door de gebruiker of een
   toekomstig opruimscript worden verwijderd.
7. **Snapshotgenerator:** de eigen `41_snapshots-btrfs` ondersteunt geen
   aparte `/boot`-partitie. Als die in een latere fase wordt toegevoegd,
   moet de generator worden uitgebreid of alsnog grub-btrfs worden
   geïmporteerd.

## Logboek

| Datum | Gebeurtenis |
|---|---|
| 2026-11-04 | Plan gelezen; werktitel LinuxBeOS vastgesteld. Fase 0 gestart. |
| 2026-11-04 | Repo-structuur, projectconfiguratie, build- en testscripts aangemaakt. |
| 2026-11-04 | Hostcontrole en statische controle geslaagd. |
| 2026-11-04 | Debian Sid build-VM aangemaakt; live-build 20250814 geïnstalleerd. |
| 2026-11-04 | Eerste buildstop: `--bootstrap`/`--volatile` bestaan niet meer in live-build 20250814; opties verwijderd. |
| 2026-11-04 | Tweede buildstop: `network-manager-gnome` heeft geen kandidaat in Sid; vervangen door `network-manager-applet`. |
| 2026-11-04 | ISO succesvol gebouwd (1,4 GiB). |
| 2026-11-04 | UEFI-bootstop: `insmod efi_uga` faalt met GRUB 2.14. Eigen GRUB-config toegevoegd. |
| 2026-11-04 | GRUB bleef op het menu wachten; `set timeout=3` toegevoegd. |
| 2026-11-04 | UEFI- en BIOS-rooktest geslaagd; screenshots opgenomen in `docs/screenshots/`. |
| 2026-11-04 | Schone-checkouttest: `git archive HEAD` naar `/tmp/opencode/linuxbeos-clean`, gebouwd met gedeelde build-VM/cache; beide rooktesten geslaagd. |
| 2026-11-04 | Fase 1 gestart: Calamares-configuratie, branding, packages en testhulpjes toegevoegd. |
| 2026-11-04 | Eerste Calamares-build: Qt xcb-plugin vereist `libxcb-cursor0`; toegevoegd aan de pakketlijst. |
| 2026-11-04 | Autoinstall-hulp schreef naar `/var/log` (niet schrijfbaar voor `live`); log verplaatst naar `/tmp` en DMI-uitlezing via sudo. |
| 2026-11-04 | Calamares met `-c` vereist een `qml/`-map in de configuratiemap; chroot-hook `0200-calamares.chroot` kopieert die. |
| 2026-11-04 | Installatietest faalt nu binnen ~5 minuten als de autoinstall-hulp niet start, in plaats van pas na de volledige timeout. |
| 2026-11-04 | UEFI-installatietest geslaagd: Calamares installeert op ext4 en het doel systeem boot zelfstandig tot een Xfce-sessie. |
| 2026-11-04 | BIOS-installatietest geslaagd: idem met SeaBIOS/MBR. |
| 2026-11-04 | Sessiemarkering op het doel systeem vereiste groep `dialout` (niet `tty`); toegevoegd aan de standaardgroepen. |
| 2026-11-04 | Installatiepictogram werd uit `/etc/skel` maar niet uit de al aangemaakte gebruikersmap verwijderd; opruimstap uitgebreid. |
| 2026-11-04 | Screenshots van beide geïnstalleerde systemen toegevoegd aan `docs/screenshots/`. |
| 2026-11-05 | Fase 2 gestart: Btrfs-subvolumes, Snapper, GRUB-snapshotmenu en rollbackscript toegevoegd. |
| 2026-11-05 | Eerste Btrfs-teststop: Debian-Snapper herkende de configuratie niet; `SNAPPER_CONFIGS="root"` in `/etc/default/snapper` toegevoegd. |
| 2026-11-05 | Tweede stop: `BTRFS_SUBVOLUMES` ontbrak in de gegenereerde runtimeconfig; toegevoegd en fallback in de testhulp ingebouwd. |
| 2026-11-05 | Derde stop: GRUB-generator gebruikte `findmnt /boot` in plaats van `--target /boot`, waardoor er geen snapshot-entries werden gemaakt. |
| 2026-11-05 | Vierde stop: rollbackscript zag `/dev/vda2[/@...]` als apparaat; subvolume-suffix wordt nu gestript. |
| 2026-11-05 | Vijfde stop: `-no-reboot` liet QEMU na de eerste herstart stoppen; optie uit de testharness verwijderd. |
| 2026-11-05 | UEFI-test geslaagd: snapshot, snapshot-boot, rollback en behoud van `/home` bewezen. |
| 2026-11-05 | BIOS-test geslaagd: idem met SeaBIOS/MBR. |
| 2026-11-05 | Screenshots van beide Btrfs-systemen toegevoegd als `phase2-installed-uefi.png` en `phase2-installed-bios.png`. |
| 2026-11-05 | Productie-opruiming verwijdert de Btrfs-testhulp; de testvariant behoudt hem via een eigen cleanup-config. |
| 2026-11-05 | Definitieve ISO gebouwd (`950c19a6…`) en beide installatie-/rollbacktests opnieuw geslaagd. |
