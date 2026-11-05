# Buildhandleiding

## Vereisten op de host

- Linux met hardware-virtualisatie (VT-x/AMD-V) en toegang tot `/dev/kvm`
- QEMU (`qemu-system-x86_64`, `qemu-img`)
- OVMF voor de UEFI-test
- `xorriso`, `curl`, `rsync`, `ssh`, `ssh-keygen`, `sha256sum`
- Minimaal ~25 GiB vrije schijfruimte en bij voorkeur 8 GiB RAM

Controleer dit met:

```sh
scripts/00-check-host.sh
```

De host heeft **geen** live-build, debootstrap of root-rechten nodig. Alles
wat met de ISO te maken heeft, gebeurt in de build-VM.

## Build-VM

```sh
scripts/01-create-build-vm.sh
```

De eerste keer:

1. Downloadt een Debian Sid `genericcloud`-image naar `.build/cache/`.
2. Maakt een qcow2-overlay van 40 GiB.
3. Genereert een SSH-sleutel in `.build/vm/id_ed25519`.
4. Maakt een cloud-init seed-ISO en start QEMU.
5. Wacht tot SSH werkt en cloud-init klaar is (inclusief pakketten).
6. Toont de status.

SSH: `ssh -p 2222 -i .build/vm/id_ed25519 builder@127.0.0.1`
(consolewachtwoord in de VM: `linuxbeos`; SSH met wachtwoord staat uit).

Beheer:

```sh
scripts/01-create-build-vm.sh --status
scripts/01-create-build-vm.sh --log      # volg de seriële console
scripts/01-create-build-vm.sh --stop
scripts/01-create-build-vm.sh --recreate # schone schijf, cloud-init opnieuw
scripts/01-create-build-vm.sh --delete
```

De cloud-init-seed bevat de publieke SSH-sleutel en het build-wachtwoord.
Beide staan alleen in `.build/` (niet in git).

## Eén commando: release bouwen en testen

```sh
scripts/20-build-release.sh
```

Dit is de aanbevolen route. Het script draait de hostcontrole, bouwt de ISO,
controleert de SHA256 en draait automatisch de statische controle en de
UEFI/BIOS-rooktesten. Daarna schrijft het `dist/release-info.txt` en
`dist/release-matrix.txt`.

```sh
scripts/20-build-release.sh --full   # plus Btrfs-installatie en rollback
scripts/20-build-release.sh --skip-build  # bestaande ISO opnieuw testen
```

Dezelfde keten via `make release` en `make release-full`. Zie
[release.md](release.md) voor het volledige releaseproces.

## ISO bouwen (los)

```sh
scripts/10-build-iso.sh
```

Dit script:

1. Draait de hostcontrole.
2. Zorgt dat de build-VM draait en cloud-init klaar is.
3. Synchroniseert de projectmap naar `/home/builder/linuxbeos-src`.
4. Voert `scripts/11-build-iso-in-vm.sh` uit als root.
5. Haalt de ISO op naar `dist/` en controleert de SHA256.
6. Schrijft `dist/SHA256SUMS` en `dist/build-info.txt`.

Opties:

```sh
scripts/10-build-iso.sh --keep-workdir     # hergebruik buildmap/cache
scripts/10-build-iso.sh --no-sync          # gebruik bestaande bron in de VM
scripts/10-build-iso.sh --skip-host-check  # sla de hostcontrole over
scripts/10-build-iso.sh --local            # bouw op een Debian Sid-host
```

Voor een build vanuit een schone checkout (of CI) kunnen de artefactpaden
buiten de checkout wijzen, zodat de bestaande build-VM en cache worden
hergebruikt:

```sh
LINUXBEOS_BUILD_DIR=/pad/naar/bestaande/.build \
  scripts/10-build-iso.sh
```

Beschikbare variabelen: `LINUXBEOS_BUILD_DIR` (VM, cache en logs),
`LINUXBEOS_DIST_DIR` (ISO-uitvoer) en `LINUXBEOS_TEST_VM_DIR` (test-VM's).

De eerste build duurt lang: debootstrap van Sid, ca. 1,5-2 GB aan pakketten
(XFCE, Firefox ESR, firmware), squashfs en ISO. Latere builds zijn sneller
doordat de live-build-pakketcache bewaard blijft.

## Live-buildconfiguratie

| Pad | Functie |
|---|---|
| `config/project.conf` | centrale naam, versie, mirror, live-gebruiker, VM-instellingen |
| `build/live-build/auto/config` | alle `lb config`-opties |
| `build/live-build/config/package-lists/` | pakketten |
| `build/live-build/config/bootloaders/grub-pc/config.cfg` | override van live-build's GRUB-menuconfiguratie |
| `build/live-build/config/hooks/live/` | chroot-hooks (services, sudo) |
| `build/live-build/config/includes.chroot/` | bestanden in de live-ISO |
| `installer/calamares/` | Calamares-configuratie; de build kopieert die naar `/etc/calamares` en `/etc/calamares-auto` |
| `btrfs/` | Snapper-config, GRUB-snapshotgenerator, rollback- en testscripts; de build kopieert die naar de ISO |
| `desktop/` | xfwm4-, GTK-, icoon-, cursor- en achtergrondassets; de build kopieert die naar de ISO |
| `overlays/` | xfconf-standaardwaarden, LightDM-greeterconfiguratie en themascripts; de build kopieert die naar de ISO |

De GRUB-override is nodig omdat live-build 20250814 `insmod efi_uga` doet,
terwijl GRUB 2.14 in Debian Sid die module niet meer levert. Zonder override
stopt de UEFI-boot voordat het menu verschijnt. De override zet ook
`set timeout=3`; live-build's sjabloon laat het menu anders oneindig wachten.

Pas je iets aan, dan is een nieuwe `scripts/10-build-iso.sh` voldoende. De
buildmap wordt standaard schoon opgebouwd; de pakketcache blijft bewaard.

## Thema-assets (fase 3)

De thema-assets staan als bron in `desktop/`. De meeste zijn klaar voor
gebruik (SVG's en PNG's). De xfwm4-afbeeldingen, de Xcursor-bestanden en de
achtergronden worden gegenereerd met:

```sh
python3 desktop/tools/generate-assets.py
```

Dit vereist Python 3 met Pillow, ImageMagick (`convert`) en `xcursorgen` op
de host. De gegenereerde bestanden worden mee gecommit, zodat de ISO-build
zelf geen renderprogramma's nodig heeft. Wijzig je een asset, genereer
opnieuw en commit zowel de bron als het resultaat.

De build plaatst daarna:

- `/usr/share/themes/LinuxBeOS/` (xfwm4 + GTK2 + GTK3);
- `/usr/share/themes/LinuxBeOS-Dark/` (donkere GTK2 + GTK3);
- `/usr/share/icons/LinuxBeOS/` (iconen en cursors);
- `/usr/share/backgrounds/linuxbeos/` (bureaublad en greeter);
- `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/` (standaardwaarden);
- `/etc/lightdm/lightdm-gtk-greeter.conf.d/99-linuxbeos.conf`.

De chroot-hook `0300-theme.chroot` werkt de caches bij. Zie
[theme.md](theme.md) voor ontwerp, licenties en de visuele checklist.

## Rooktesten

```sh
tests/test-uefi.sh
tests/test-bios.sh
```

Beide starten de ISO met een lege 20 GiB qcow2-schijf onder `tests/vm/`.
Headless (standaard) wachten ze op de regel:

```
LINUXBEOS_SMOKE session=xfce network=connected
LINUXBEOS_THEME ok xfwm4=LinuxBeOS gtk=LinuxBeOS icons=LinuxBeOS cursor=LinuxBeOS deskbar=top-right wallpaper=ok skel=ok xdg=ok dark=ok
```

in `tests/vm/<uefi|bios>/serial.log`. Bij succes wordt een screenshot gemaakt
(`tests/vm/<mode>/screenshot.png`) en wordt QEMU gestopt. Bij falen wordt de
laatste 60 regels van het seriële log getoond.

Opties:

```sh
tests/test-uefi.sh --gui            # QEMU-venster; sluit het om af te ronden
tests/test-uefi.sh --iso path.iso   # andere ISO testen
tests/test-uefi.sh --timeout 600    # langere timeout
tests/test-uefi.sh --keep           # testmap bewaren
tests/test-uefi.sh --skip-theme     # diagnose zonder themacontrole
tests/test-uefi.sh --no-demo        # geen terminal/Thunar voor de vensterscreenshot
```

De test maakt twee screenshots: `screenshot.png` van het bureaublad en
`screenshot-windows.png` met de testvensters van `linuxbeos-theme-demo`.
Die laatste wordt alleen geopend als de VM het SMBIOS-seriënnummer
`LINUXBEOS-THEME-DEMO` heeft; `--no-demo` schakelt dat uit.

## Installatietests (fase 2)

```sh
tests/test-install-uefi.sh
tests/test-install-bios.sh
```

Deze tests doen nu vier stappen binnen dezelfde QEMU-sessie:

1. De live-ISO start in een lege VM met het SMBIOS-kenmerk
   `LINUXBEOS-AUTOINSTALL`. De live-sessie start Calamares automatisch met
   `/etc/calamares-auto` en installeert op Btrfs (inclusief `@swap`).
2. Dezelfde schijf wordt zonder ISO opnieuw gestart. De test wacht op
   `LINUXBEOS_INSTALLED_READY` en op de Btrfs-layoutcontrole.
3. De testhulp maakt een Snapper-snapshot, controleert de GRUB-entry, breekt
   een testmarker en herstart vanaf de snapshot (read-only).
4. Na de rollback start het systeem weer van `@`; de test controleert dat de
   marker hersteld is, `/home` behouden is en de Xfce-sessie met netwerk
   werkt.

De verwachte eindmarkering is:

```
LINUXBEOS_BTRFS_TEST done
```

Artefacten staan onder `tests/vm/install-<mode>/`:

| Bestand | Inhoud |
|---|---|
| `disk.qcow2` | de geïnstalleerde schijf (20 GiB) |
| `install-serial.log` | console van de installatiefase |
| `boot-serial.log` | console van alle drie de doel-boots |
| `installed-system.png` | screenshot van het teruggezette systeem |
| `install-result.txt`, `boot-result.txt` | resultaat per fase, inclusief Btrfs-markeringen |

Opties:

```sh
tests/test-install-uefi.sh --keep             # schijf en logs bewaren
tests/test-install-uefi.sh --install-timeout 2400
tests/test-install-uefi.sh --boot-timeout 1800
tests/test-install-uefi.sh --iso path.iso
```

De test faalt voortaan binnen enkele minuten als de autoinstall-hulp niet
start; het wachten op de eigenlijke installatie heeft een ruime maar
begrensde timeout.

## Releasematrix

```sh
tests/release-matrix.sh
```

De matrix is de releasegate en draait:

1. de statische projectcontrole;
2. de UEFI- en BIOS-rooktest (sessie, netwerk, thema en `/etc/skel`);
3. de UEFI- en BIOS-installatie op Btrfs;
4. het thema op het geïnstalleerde systeem;
5. snapshot maken, snapshot-boot en rollback met behoud van `/home`;
6. de vergelijking “geïnstalleerd systeem = live-look”.

Het resultaat staat in `dist/release-matrix.txt`; bij een ontbrekende marker
stopt de matrix met een fout. Met `--keep` blijven de qcow2-schijven,
logboeken en screenshots onder `tests/vm/` bewaard. Zie
[release.md](release.md) voor de volledige releaseprocedure.

## Handmatige controle

Voor een visuele controle:

```sh
tests/test-uefi.sh --gui
tests/test-bios.sh --gui
```

De live-sessie logt automatisch in als `live`. Controleer:

- XFCE-panel en desktop verschijnen
- NetworkManager is verbonden (pictogram in de panel)
- Firefox ESR opent een pagina
- `nmcli -t -f STATE general` geeft `connected`
- `pipewire`/`wpctl status` tonen een audioserver
- Vensters hebben de gele BeOS-tab en de knoppen links/rechts
- De Deskbar staat rechtsboven met menu, vensterlijst en klok
- De achtergrond, iconen en cursor zijn van LinuxBeOS
- `xfconf-query -c xfwm4 -p /general/theme` geeft `LinuxBeOS`

De volledige visuele checklist staat in [theme.md](theme.md).

## Opruimen

```sh
scripts/01-create-build-vm.sh --stop
rm -rf .build dist tests/vm
```

Verwijder nooit fysieke schijven: alle scripts werken uitsluitend met
qcow2-bestanden onder `.build/`, `dist/` en `tests/vm/`.
