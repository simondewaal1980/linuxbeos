# Architectuur

## Doel

LinuxBeOS is een Debian Sid-distributie met een BeOS 5-geïnspireerde
XFCE-desktop. De architectuur is bewust in fasen opgebouwd zodat elke laag
afzonderlijk testbaar is.

## Lagen

```
+-------------------------------------------------------------+
| Live-sessie (fase 0)                                        |
|   GRUB (UEFI + BIOS) -> Linux -> live-boot -> systemd       |
|   LightDM (autologin) -> XFCE -> NetworkManager/PipeWire    |
+-------------------------------------------------------------+
| Installer (fase 1/2)                                        |
|   Calamares -> partitioneren, mount, unpackfs, fstab, GRUB  |
+-------------------------------------------------------------+
| Doelsysteem (fase 2/3)                                      |
|   Btrfs-subvolumes, Snapper, grub-btrfs, BeOS-thema         |
+-------------------------------------------------------------+
```

## Buildketen

De host is geen Debian Sid en heeft geen passwordless sudo. Daarom bouwt de
host niet zelf, maar beheert hij een geïsoleerde VM:

1. `scripts/00-check-host.sh` controleert QEMU/KVM, OVMF, netwerk, schijfruimte
   en de statische projectconfiguratie.
2. `scripts/01-create-build-vm.sh` downloadt een Debian Sid
   `genericcloud`-qcow2, maakt een overlay-schijf van 40 GiB, genereert een
   cloud-init seed-ISO en start QEMU met user-networking. SSH-poort 22 van de
   guest wordt geforward naar `127.0.0.1:2222`.
3. Cloud-init maakt de gebruiker `builder` (SSH-sleutel, passwordless sudo) en
   installeert live-build, debootstrap, squashfs-tools, xorriso, mtools,
   dosfstools en de GRUB-pakketten.
4. `scripts/10-build-iso.sh` synchroniseert de projectmap met rsync naar
   `/home/builder/linuxbeos-src` en voert daar `scripts/11-build-iso-in-vm.sh`
   uit.
5. `scripts/11-build-iso-in-vm.sh` kopieert `build/live-build/auto` en
   `config/` naar een schone bouwmap en draait `lb build`.
6. De ISO wordt teruggehaald naar `dist/`, gecontroleerd op SHA256 en
   voorzien van `SHA256SUMS` en `build-info.txt`.

Er wordt geen gedeelde map gebruikt: de VM ziet alleen wat via rsync is
gekopieerd. Dit voorkomt permissie- en isolatieproblemen.

## Waarom directe QEMU en geen libvirt?

De host repot staat onder `/home/simon`, dat voor andere gebruikers niet
toegankelijk is. `qemu:///system` draait QEMU als `libvirt-qemu` en kan daar
niet bij de schijven. De gebruiker heeft via een ACL wel toegang tot
`/dev/kvm`. Directe QEMU in de gebruikerssessie is daarom eenvoudiger,
vereist geen sudo en houdt de build-VM geïsoleerd. Dezelfde aanpak wordt voor
de test-VM's gebruikt.

## Live-build

- Distributie: Debian Sid, amd64
- Bootloaders: `grub-efi` + `grub-pc`, hybride ISO
- Chroot: squashfs, xz-compressie
- Init: systemd
- Live-gebruiker: `live`, autologin via LightDM
- Console: `tty0` en `ttyS0` (voor de geautomatiseerde rooktest)
- Netwerk: NetworkManager met DHCP
- Audio: PipeWire + WirePlumber

De pakketlijst staat in
`build/live-build/config/package-lists/desktop.list.chroot`. Services worden
ingeschakeld in `build/live-build/config/hooks/live/0100-services.chroot`.
Bestanden die in de live-ISO horen staan onder
`build/live-build/config/includes.chroot/`.

Het GRUB-menu wordt overschreven via
`build/live-build/config/bootloaders/grub-pc/config.cfg`. Reden: live-build
20250814 doet `insmod efi_uga`, maar GRUB 2.14 in Sid levert die module niet
meer; bovendien zet het standaardsjabloon geen timeout, waardoor het menu
oneindig blijft wachten.

## Calamares (fase 1/2)

De installer-configuratie staat onder `installer/calamares/`. Tijdens de
build kopieert `scripts/11-build-iso-in-vm.sh` die naar:

- `/etc/calamares` — productieconfiguratie;
- `/etc/calamares-auto` — dezelfde configuratie met voorgeselecteerde
  partitie- en gebruikerskeuzes voor de geautomatiseerde VM-test.

Calamares wordt als root gestart via `/usr/local/bin/linuxbeos-installer`
(met `sudo`) of automatisch via `/usr/local/bin/linuxbeos-autoinstall`
wanneer de VM het SMBIOS-seriënnummer `LINUXBEOS-AUTOINSTALL` heeft.
De productieketen installeert op Btrfs met subvolumes en verwijdert daarna
Calamares en de live-pakketten uit het doel. Zie [calamares.md](calamares.md)
en [btrfs-layout.md](btrfs-layout.md) voor details.

## Btrfs, Snapper en rollback (fase 2)

De build kopieert `btrfs/` naar de ISO:

- `btrfs/snapper/root` → `/etc/snapper/configs/root`
- `btrfs/snapper/default` → `/etc/default/snapper` (`SNAPPER_CONFIGS=root`)
- `btrfs/grub.d/41_snapshots-btrfs` → `/etc/grub.d/`
- `btrfs/bin/linuxbeos-rollback` en `linuxbeos-update-grub` →
  `/usr/local/bin` (en als sbin-symlink)
- `btrfs/systemd/*` → `/etc/systemd/system/`

De root-subvolume `@` wordt door Snapper gesnapshot. `@home`, `@var_log`,
`@var_cache` en `@snapshots` zijn aparte subvolumes, zodat een rollback van
`/` de gebruikersdata intact laat. Een eigen generator zet de snapshots als
read-only entries in GRUB; `grub-btrfs.service` en `grub-btrfs.path` houden
het menu actueel. `linuxbeos-rollback` vervangt `@` door een schrijfbare
kopie van een snapshot en bewaart de oude root als `@.broken-<tijdstip>`.

De geautomatiseerde test doorloopt drie boots en schrijft markeringen naar
de seriële console; zie [development-progress.md](development-progress.md)
voor de bewijzen.

Het geïnstalleerde systeem schrijft bij het bereiken van `graphical.target`
een marker via `linuxbeos-installed-ready.service`; de gewone Xfce-sessie
schrijft de bestaande `LINUXBEOS_SMOKE`-regel. Daarmee test
`tests/lib/run-install-test.sh` zowel de installatie als de zelfstandige
boot van het doel systeem.

## Rooktesten

`tests/test-uefi.sh` en `tests/test-bios.sh` starten de ISO met een lege
qcow2-schijf. UEFI gebruikt OVMF, BIOS gebruikt SeaBIOS. De live-sessie start
via LightDM automatisch een XFCE-sessie. Een autostartscript wacht tot
NetworkManager verbonden is en schrijft dan één regel naar `/dev/ttyS0`:

```
LINUXBEOS_SMOKE session=xfce network=connected
```

De testscripts lezen het seriële log en slagen alleen als die regel verschijnt.
Zo wordt de hele keten getest: firmware → GRUB → kernel → live-boot → systemd
→ LightDM → XFCE → netwerk.

## Roadmap

| Fase | Laag |
|---|---|
| 0 | Live-build-pipeline en minimale desktop |
| 1 | Calamares op ext4; installatieketen valideren |
| 2 | Btrfs-subvolumes, Snapper, grub-btrfs en rollback |
| 3 | BeOS 5-thema: xfwm4, GTK, Deskbar, iconen, cursor, achtergrond |
| 4 | Integratie, één-commando-build, testmatrix en releaseproces |
