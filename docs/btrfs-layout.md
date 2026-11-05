# Btrfs-layout, snapshots en rollback (fase 2 en 4)

LinuxBeOS installeert standaard op **Btrfs** met aparte subvolumes. De
root-subvolume wordt met `compress=zstd` en `noatime` gemount; `/home` en de
log-/cache-subvolumes blijven bij een rollback van `/` intact.

## Subvolume-indeling

De namen staan centraal in `config/project.conf` (`BTRFS_*_SUBVOL`). Calamares
maakt ze tijdens de installatie aan via `installer/calamares/modules/mount.conf`.

| Subvolume | Mountpoint | Mountopties | Doel |
|---|---|---|---|
| `@` | `/` | `compress=zstd,noatime` | systeem; wordt gesnapshot en teruggerold |
| `@home` | `/home` | `compress=zstd,noatime` | gebruikersdata; blijft behouden bij rollback |
| `@snapshots` | `/.snapshots` | `compress=zstd,noatime` | Snapper-snapshots; buiten de root-snapshot |
| `@var_log` | `/var/log` | `compress=zstd,noatime` | logboeken; blijven behouden bij rollback |
| `@var_cache` | `/var/cache` | `compress=zstd,noatime` | pakketcache; geen snapshots |
| `@swap` | `/swap` | `noatime`, geen compressie | swapfile zonder CoW (`chattr +C`) |

`@swap` wordt alleen aangemaakt als tijdens de installatie voor een
**swapfile** is gekozen. De standaardkeuze is `file`; gebruikers kunnen ook
zonder swap installeren. Er is bewust **niet** voor zram gekozen: een
swapfile in een eigen subvolume is met Calamares' ingebouwde
`btrfsSwapSubvol`-ondersteuning direct te testen en te beheren.

Het swapfile is 512 MiB (Calamares-standaard) en staat in `@swap`, dat niet
wordt gesnapshot. Daardoor kan een rollback het swapfile niet corrumperen.

## fstab en GRUB

De mount-module van Calamares schrijft per subvolume een fstab-regel:

```
UUID=<uuid> /          btrfs subvol=/@,defaults,noatime,compress=zstd 0 0
UUID=<uuid> /home      btrfs subvol=/@home,defaults,noatime,compress=zstd 0 0
UUID=<uuid> /.snapshots btrfs subvol=/@snapshots,defaults,noatime,compress=zstd 0 0
UUID=<uuid> /var/log   btrfs subvol=/@var_log,defaults,noatime,compress=zstd 0 0
UUID=<uuid> /var/cache btrfs subvol=/@var_cache,defaults,noatime,compress=zstd 0 0
UUID=<uuid> /swap      btrfs subvol=/@swap,defaults,noatime 0 0
/swap/swapfile none swap defaults 0 0
```

Calamares zet daarnaast `rootflags=subvol=/@` in het GRUB-kernelcommando.
De fstab-module voegt `subvol=` zelf toe; `mountOptions` horen daarom in
`mount.conf`, niet in `fstab.conf`.

## Snapper

De configuratie staat in `btrfs/snapper/root` en wordt tijdens de build naar
`/etc/snapper/configs/root` gekopieerd. Snapper beheert alleen de
root-subvolume `/` (dus `@`).

| Onderdeel | Instelling |
|---|---|
| Tijdlijn-snapshots | `snapper-timeline.timer` (elk uur) |
| Opruiming | `snapper-cleanup.timer` (dagelijks) |
| Bewaarbeleid | 5 uur, 7 dagen, 4 weken, 6 maanden, 0 jaar |
| Aantal-snapshots | max. 30, waarvan 10 belangrijk |
| apt-hook | `/etc/apt/apt.conf.d/80snapper` (door het Debian-pakket) |
| Handmatig | `sudo snapper -c root create -d "omschrijving"` |

De timers worden door Calamares' `services-systemd`-module in het
doelsysteem ingeschakeld. De apt-hook maakt automatisch een pre/post-paar
rond pakketbeheer zodra `/etc/snapper/configs/root` bestaat.

Snapshots van `@` bevatten alleen het systeem. `/home`, `/var/log`,
`/var/cache` en `/.snapshots` zijn aparte subvolumes en worden dus niet mee
teruggerold.

## Snapshots in het GRUB-menu

Debian Sid levert geen `grub-btrfs`-pakket. LinuxBeOS gebruikt daarom een
kleine eigen generator in dezelfde geest:

- `btrfs/grub.d/41_snapshots-btrfs` draait tijdens `grub-mkconfig` en zet
  elke Snapper-snapshot als read-only menu-entry in het GRUB-menu;
- `btrfs/bin/linuxbeos-update-grub` regenereert `grub.cfg`;
- `grub-btrfs.service` doet dat bij elke boot;
- `grub-btrfs.path` doet dat zodra `/.snapshots` verandert.

Een snapshot-entry gebruikt de Btrfs-top-level, bijvoorbeeld:

```
linux /@snapshots/3/snapshot/boot/vmlinuz-... \
  root=UUID=<uuid> rootflags=subvol=/@snapshots/3/snapshot ro
```

Belangrijk: `@snapshots` is een zustervolume van `@`. Het pad is daarom
`/@snapshots/<nummer>/snapshot`, **niet** `@/.snapshots/<nummer>/snapshot`.
De generator ondersteunt alleen een `/boot` die in de root-subvolume zit;
een aparte `/boot`-partitie wordt in deze fase niet ondersteund.

## Rollbackprocedure

Een rollback vervangt de root-subvolume `@` door een schrijfbare kopie van
een snapshot. `/home` en de andere subvolumes blijven staan.

### Vanuit het GRUB-menu (aanbevolen)

1. Herstart en kies in GRUB een entry `LinuxBeOS snapshot <nummer> - ...`.
   Het systeem start read-only vanaf de snapshot.
2. Log in (de snapshot bevat dezelfde gebruiker en hetzelfde wachtwoord).
3. Controleer eerst dat de gewenste toestand terug is, bijvoorbeeld:
   ```sh
   snapper -c root list
   ```
4. Voer de rollback uit:
   ```sh
   sudo linuxbeos-rollback <nummer>
   ```
5. Herstart. Het systeem start nu weer van de nieuwe `@`.

Het script:

- mount de Btrfs-top-level (`subvolid=5`);
- hernoemt de huidige `@` naar `@.broken-<UTC-tijdstip>`;
- maakt van `@snapshots/<nummer>/snapshot` een nieuwe, schrijfbare `@`;
- laat `@home`, `@var_log`, `@var_cache` en `@snapshots` ongemoeid.

De oude root blijft als `@.broken-...` bewaard. Na controle kan die worden
verwijderd:

```sh
sudo mount -o subvolid=5 /dev/sda2 /mnt
sudo btrfs subvolume delete /mnt/@.broken-...
sudo umount /mnt
```

### Vanuit de live-ISO

Als het systeem niet meer vanaf een snapshot wil starten:

```sh
sudo linuxbeos-rollback --list
sudo linuxbeos-rollback --device /dev/sda2 <nummer>
```

Het script weigert te draaien vanuit de actieve `@` zelf; start dus altijd
eerst een snapshot of gebruik de live-ISO.

## Handmatige controles

```sh
findmnt -no SOURCE,FSTYPE,OPTIONS /
btrfs subvolume list /
btrfs subvolume list / | awk '{print $NF}' | sort
snapper -c root list
snapper -c root get-config
grep -E 'subvol=|compress=zstd' /etc/fstab
grep -c 'linuxbeos-snapshot-' /boot/grub/grub.cfg
```

Verwacht: `@`, `@home`, `@snapshots`, `@var_log`, `@var_cache` en (bij een
swapfile) `@swap`; fstab-regels met de juiste `subvol=`; minstens één
snapshot-entry in `grub.cfg` zodra er een snapshot bestaat.

## Geautomatiseerde acceptatietest

`tests/test-install-uefi.sh` en `tests/test-install-bios.sh` installeren op
Btrfs en doorlopen daarna automatisch drie boots:

1. layout en Snapper controleren, snapshot maken, GRUB-entry controleren,
   testmarker breken en herstarten;
2. vanaf de snapshot booten, controleren dat de marker weer `original` is,
   de rollback uitvoeren en herstarten;
3. controleren dat `@` terug is, `/home` bewaard is en de Xfce-sessie met
   netwerk werkt.

De markeringen op de seriële console zijn:

```
LINUXBEOS_BTRFS_LAYOUT ok ...
LINUXBEOS_BTRFS_SNAPSHOT ok number=N
LINUXBEOS_BTRFS_GRUB ok number=N
LINUXBEOS_BTRFS_SNAPSHOT_BOOT ok number=N ...
LINUXBEOS_BTRFS_ROLLBACK ok ... home=preserved
LINUXBEOS_BTRFS_TEST done
```

Sinds fase 4 is dit onderdeel van de releasegate. `tests/release-matrix.sh`
draait dezelfde test op UEFI én BIOS, controleert daarnaast het thema op het
geïnstalleerde systeem en legt alle bewijzen vast in
`dist/release-matrix.txt`. Een release zonder `home=preserved` is niet
toegestaan.

## Beperkingen

- Snapshot-boot is read-only; dat is inherent aan Snapper-snapshots.
- Een aparte `/boot`-partitie wordt niet ondersteund door de
  snapshot-generator.
- De oude root (`@.broken-...`) wordt niet automatisch opgeruimd.
- Snapper beheert alleen `@`; gebruikersdata in `/home` moet via de eigen
  back-upvoorziening worden beschermd.
