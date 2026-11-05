# Calamares-installer (fase 1 en 2)

Deze pagina beschrijft hoe de grafische installer in LinuxBeOS is opgenomen,
welke moduleketen wordt gebruikt en hoe de geautomatiseerde installatietest
werkt.

## Uitgangspunten

- Calamares 3.4.x uit Debian Sid.
- Sinds fase 2 is **Btrfs** de standaard: root-subvolumes, `compress=zstd`,
  Snapper en een GRUB-menu met snapshots. Ext4 blijft via handmatige
  partitionering mogelijk.
- Eén schijf, één gebruiker, GRUB voor UEFI én BIOS.
- De installer is na de installatie niet meer in het doelsysteem aanwezig.
- De configuratie staat één keer in de repository onder
  `installer/calamares/`; de build kopieert die naar `/etc/calamares` in de
  live-ISO.

## Moduleketen

De zichtbare pagina's zijn:

1. `welcome`
2. `locale`
3. `keyboard`
4. `partition`
5. `users`
6. `summary`

Daarna voert Calamares uit:

| Module | Functie |
|---|---|
| `partition` | schijf partitioneren (GPT+ESP voor UEFI, msdos/MBR voor BIOS); standaard Btrfs |
| `mount` | doelsysteem, virtuele bestandssystemen en Btrfs-subvolumes mounten |
| `unpackfs` | `/run/live/medium/live/filesystem.squashfs` uitpakken |
| `machineid` | nieuwe machine-id en D-Bus-id |
| `fstab` | `/etc/fstab` schrijven, inclusief `subvol=` en `compress=zstd` |
| `locale`, `keyboard`, `localecfg` | locale, tijdzone en toetsenbord |
| `users` | gebruiker, groepen, wachtwoord en sudo |
| `displaymanager` | LightDM en Xfce-sessie |
| `networkcfg`, `hwclock` | netwerkconfiguratie en klok |
| `services-systemd` | NetworkManager, LightDM en graphical.target |
| `grubcfg` | `/etc/default/grub`, inclusief seriële console |
| `bootloader` | GRUB installeren voor de actieve firmware |
| `packages` | Calamares en live-pakketten uit het doel verwijderen |
| `shellprocess@target-cleanup` | live-autologin en testhulpjes opruimen |
| `umount` | doelsysteem netjes ontkoppelen |

## Configuratie

```
installer/calamares/
├── settings.conf                 productieketen
├── branding/linuxbeos/           naam, logo, kleuren, slideshow
├── modules/                      productieconfiguratie per module
└── auto/
    ├── settings.conf             testvariant (quit-at-end)
    └── modules/                  voorgeselecteerde partitie/gebruiker
```

De productieconfiguratie gebruikt `initialPartitioningChoice: none`: de
gebruiker moet bewust een schijf en installatiemethode kiezen. De standaard
is Btrfs met een swapfile in `@swap`; zonder swap is ook mogelijk. LUKS en
LVM zijn nog niet ondersteund.

De subvolume-indeling, mountopties, Snapper-configuratie en rollback staan
in [btrfs-layout.md](btrfs-layout.md). De mount-module maakt de subvolumes
aan; de fstab-module neemt de `subvol=`- en compressie-opties over.

De testvariant (`/etc/calamares-auto`) gebruikt:

- `initialPartitioningChoice: erase` op de enige schijf;
- Btrfs met een swapfile, zodat ook `@swap` wordt getest;
- vaste gebruiker `testuser` via `presets`;
- `quit-at-end: true`, zodat Calamares na de installatie afsluit;
- een `shellprocess`-stap die het wachtwoord `testpass` zet;
- een extra ingeschakelde dienst voor de Btrfs-rollbacktest.

## Automatische acceptatietest

`tests/test-install-uefi.sh` en `tests/test-install-bios.sh` starten QEMU met
een lege qcow2-schijf en het SMBIOS-kenmerk
`LINUXBEOS-AUTOINSTALL`. In de live-sessie start
`/usr/local/bin/linuxbeos-autoinstall` dan Calamares met de testconfiguratie.
De hulp doorloopt de pagina's met de toetsenbord-mnemonics van Calamares en
schrijft markeringen naar de seriële console:

```
LINUXBEOS_AUTOINSTALL start
LINUXBEOS_AUTOINSTALL done
```

Daarna start de test dezelfde schijf zonder ISO opnieuw. Het geïnstalleerde
systeem schrijft via `linuxbeos-installed-ready.service`:

```
LINUXBEOS_INSTALLED_READY hostname=...
```

Sinds fase 2 doorloopt `/usr/local/bin/linuxbeos-btrfs-test` (alleen actief
bij hetzelfde SMBIOS-kenmerk) daarna automatisch drie boots:

1. **layout + snapshot** — controleert subvolumes, fstab, Snapper en de
   GRUB-entry, maakt een snapshot, breekt een testmarker en herstart;
2. **snapshot-boot** — start read-only vanaf de snapshot, controleert dat de
   marker weer `original` is, voert `linuxbeos-rollback` uit en herstart;
3. **rollback** — controleert dat `@` terug is, `/home` bewaard is en de
   Xfce-sessie met netwerk werkt.

De bijbehorende markeringen zijn:

```
LINUXBEOS_BTRFS_LAYOUT ok ...
LINUXBEOS_BTRFS_SNAPSHOT ok number=N
LINUXBEOS_BTRFS_GRUB ok number=N
LINUXBEOS_BTRFS_SNAPSHOT_BOOT ok number=N subvol=/@snapshots/N/snapshot
LINUXBEOS_BTRFS_ROLLBACK ok number=N marker=original home=preserved
LINUXBEOS_BTRFS_TEST done
```

en de autologin-sessie schrijft de bestaande rookmarkering:

```
LINUXBEOS_SMOKE session=xfce network=connected
```

De test slaagt alleen als de installatie, de zelfstandige boot, de
snapshot-boot, de rollback en de Xfce-sessie op het teruggezette systeem
allemaal aantoonbaar zijn geslaagd.

### Bewijs

| Controle | UEFI | BIOS |
|---|---|---|
| Installatie | geslaagd | geslaagd |
| Zelfstandige boot | `LINUXBEOS_INSTALLED_READY` | `LINUXBEOS_INSTALLED_READY` |
| Btrfs-layout | `LINUXBEOS_BTRFS_LAYOUT ok` | idem |
| Snapshot in GRUB | `LINUXBEOS_BTRFS_GRUB ok` | idem |
| Boot vanaf snapshot | `LINUXBEOS_BTRFS_SNAPSHOT_BOOT ok` | idem |
| Rollback + /home behouden | `LINUXBEOS_BTRFS_ROLLBACK ok ... home=preserved` | idem |
| Xfce-sessie | `LINUXBEOS_SMOKE session=xfce network=connected` | idem |
| Screenshot | [phase2-installed-uefi.png](screenshots/phase2-installed-uefi.png) | [phase2-installed-bios.png](screenshots/phase2-installed-bios.png) |

## Handmatige installatie testen

```sh
# Live-ISO met venster starten
tests/test-install-uefi.sh --keep   # of: tests/test-install-bios.sh
```

Voor een handmatige kliktest kan de ISO ook met `--gui` uit de gewone
rooktest worden gestart:

```sh
tests/test-uefi.sh --gui
```

Start daarna in de live-sessie de installer via het bureaubladpictogram of
het menu (`Install LinuxBeOS`).

## Beperkingen

- Standaard Btrfs; ext4 alleen via handmatige partitionering.
- Geen encryptie (LUKS) en geen LVM.
- Geen Secure Boot-ondersteuning.
- Snapshot-boot is read-only en ondersteunt geen aparte `/boot`-partitie.
- De testvariant staat in de ISO maar is alleen actief bij het
  SMBIOS-kenmerk; in een normale sessie wordt hij niet gestart.
