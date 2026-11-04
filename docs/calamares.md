# Calamares-installer (fase 1)

Deze pagina beschrijft hoe de grafische installer in LinuxBeOS is opgenomen,
welke moduleketen wordt gebruikt en hoe de geautomatiseerde installatietest
werkt.

## Uitgangspunten

- Calamares 3.4.x uit Debian Sid.
- Eerste installaties op **ext4**, zodat de keten los van Btrfs getest kan
  worden. Btrfs met subvolumes volgt in fase 2.
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
| `partition` | schijf partitioneren (GPT+ESP voor UEFI, msdos/MBR voor BIOS) |
| `mount` | doelsysteem en virtuele bestandssystemen mounten |
| `unpackfs` | `/run/live/medium/live/filesystem.squashfs` uitpakken |
| `machineid` | nieuwe machine-id en D-Bus-id |
| `fstab` | `/etc/fstab` schrijven |
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
gebruiker moet bewust een schijf en installatiemethode kiezen. LUKS en LVM
zijn in fase 1 uitgeschakeld omdat ze nog niet getest zijn.

De testvariant (`/etc/calamares-auto`) gebruikt:

- `initialPartitioningChoice: erase` op de enige schijf;
- vaste gebruiker `testuser` via `presets`;
- `quit-at-end: true`, zodat Calamares na de installatie afsluit;
- een `shellprocess`-stap die het wachtwoord `testpass` zet.

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

en de autologin-sessie schrijft de bestaande rookmarkering:

```
LINUXBEOS_SMOKE session=xfce network=connected
```

De test slaagt alleen als zowel de installatie als de zelfstandige boot van
het doelsysteem aantoonbaar zijn geslaagd.

### Bewijs

| Controle | UEFI | BIOS |
|---|---|---|
| Installatie | geslaagd | geslaagd |
| Zelfstandige boot | `LINUXBEOS_INSTALLED_READY` | `LINUXBEOS_INSTALLED_READY` |
| Xfce-sessie | `LINUXBEOS_SMOKE session=xfce network=connected` | idem |
| Screenshot | [phase1-installed-uefi.png](screenshots/phase1-installed-uefi.png) | [phase1-installed-bios.png](screenshots/phase1-installed-bios.png) |

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

## Beperkingen in fase 1

- Alleen ext4; geen Btrfs-subvolumes of snapshots.
- Geen encryptie (LUKS) en geen LVM.
- Geen Secure Boot-ondersteuning.
- De testvariant staat in de ISO maar is alleen actief bij het
  SMBIOS-kenmerk; in een normale sessie wordt hij niet gestart.
