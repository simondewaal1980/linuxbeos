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

## ISO bouwen

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

De GRUB-override is nodig omdat live-build 20250814 `insmod efi_uga` doet,
terwijl GRUB 2.14 in Debian Sid die module niet meer levert. Zonder override
stopt de UEFI-boot voordat het menu verschijnt. De override zet ook
`set timeout=3`; live-build's sjabloon laat het menu anders oneindig wachten.

Pas je iets aan, dan is een nieuwe `scripts/10-build-iso.sh` voldoende. De
buildmap wordt standaard schoon opgebouwd; de pakketcache blijft bewaard.

## Rooktesten

```sh
tests/test-uefi.sh
tests/test-bios.sh
```

Beide starten de ISO met een lege 20 GiB qcow2-schijf onder `tests/vm/`.
Headless (standaard) wachten ze op de regel:

```
LINUXBEOS_SMOKE session=xfce network=connected
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
```

## Installatietests (fase 1)

```sh
tests/test-install-uefi.sh
tests/test-install-bios.sh
```

Deze tests doen twee runs:

1. De live-ISO start in een lege VM met het SMBIOS-kenmerk
   `LINUXBEOS-AUTOINSTALL`. De live-sessie start Calamares automatisch met
   `/etc/calamares-auto` en installeert op de lege schijf.
2. Dezelfde schijf wordt zonder ISO opnieuw gestart. De test wacht op
   `LINUXBEOS_INSTALLED_READY` en op de Xfce-sessiemarkering van de
   automatisch aangemaakte gebruiker.

Artefacten staan onder `tests/vm/install-<mode>/`:

| Bestand | Inhoud |
|---|---|
| `disk.qcow2` | de geïnstalleerde schijf (20 GiB) |
| `install-serial.log` | console van de installatiefase |
| `boot-serial.log` | console van de zelfstandige boot |
| `installed-system.png` | screenshot van het geïnstalleerde systeem |
| `install-result.txt`, `boot-result.txt` | resultaat per fase |

Opties:

```sh
tests/test-install-uefi.sh --keep             # schijf en logs bewaren
tests/test-install-uefi.sh --install-timeout 2400
tests/test-install-uefi.sh --boot-timeout 900
tests/test-install-uefi.sh --iso path.iso
```

De test faalt voortaan binnen enkele minuten als de autoinstall-hulp niet
start; het wachten op de eigenlijke installatie heeft een ruime maar
begrensde timeout.

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

## Opruimen

```sh
scripts/01-create-build-vm.sh --stop
rm -rf .build dist tests/vm
```

Verwijder nooit fysieke schijven: alle scripts werken uitsluitend met
qcow2-bestanden onder `.build/`, `dist/` en `tests/vm/`.
