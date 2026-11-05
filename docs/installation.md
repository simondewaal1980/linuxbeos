# Installatiehandleiding

Deze handleiding beschrijft een standaardinstallatie van LinuxBeOS 0.1 vanaf
de live-ISO. De installer is Calamares; de standaardkeuze is **Btrfs met
subvolumes en Snapper-snapshots**.

## Vereisten

- Een 64-bits x86-computer met UEFI of BIOS.
- Minimaal 20 GiB vrije schijfruimte (de testmatrix gebruikt een 20 GiB-schijf).
- Minimaal 4 GiB RAM; 8 GiB is comfortabeler.
- Een USB-stick van minimaal 2 GB of een VM met de ISO als CD-ROM.
- Netwerk is tijdens de installatie niet nodig; de doelpakketten komen uit de
  live-squashfs. Voor updates na de installatie is internet nodig.

## ISO op een USB-stick zetten

```sh
# Vervang /dev/sdX door de juiste stick; dit wist de hele stick.
sudo dd if=dist/linuxbeos-0.1-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Controleer eerst de checksum:

```sh
cd dist
sha256sum -c SHA256SUMS
```

Gebruik je een VM, koppel de ISO dan als CD-ROM en start van dat station.

## Live-sessie starten

1. Start de computer van de USB-stick of de ISO.
2. Kies in het GRUB-menu **LinuxBeOS** (de standaardoptie start automatisch).
3. De live-sessie logt automatisch in als `live` en toont de BeOS-desktop:
   gele venstertitels, een Deskbar rechtsboven, eigen pictogrammen en
   achtergrond.
4. Controleer eventueel het netwerk met het NetworkManager-pictogram in de
   Deskbar.

De live-sessie is alleen bedoeld om te testen en te installeren. Wijzigingen
in de live-sessie worden niet bewaard.

## Installeren

1. Start de installer via het bureaubladpictogram **Install LinuxBeOS** of via
   het applicatiemenu.
2. Doorloop de pagina's:
   - **Welkom** — kies de taal.
   - **Locatie** — tijdzone en toetsenbord.
   - **Partitionering** — kies de schijf en de standaardoptie **Wissen en
     installeren**. LinuxBeOS maakt automatisch GPT (UEFI) of MBR (BIOS),
     een EFI-systeempartitie en Btrfs-subvolumes.
   - **Gebruiker** — naam, gebruikersnaam, wachtwoord en hostnaam.
   - **Samenvatting** — controleer de keuzes en start de installatie.
3. De installatie kopieert de live-omgeving naar de schijf, schrijft
   `/etc/fstab` met `compress=zstd,noatime`, installeert GRUB en maakt de
   Btrfs-subvolumes aan.
4. Na de installatie wordt de computer automatisch afgesloten of herstart.
   Verwijder op tijd de USB-stick of ontkoppel de ISO.

## Eerste keer opstarten

Na de herstart start GRUB het nieuwe systeem. De aangemaakte gebruiker logt
in via LightDM. De desktop ziet er hetzelfde uit als de live-sessie:

- xfwm4 met de gele BeOS-titeltab;
- GTK2/GTK3-thema `LinuxBeOS`;
- Deskbar rechtsboven met menu, vensterlijst en klok;
- eigen pictogrammen, cursor en achtergrond;
- Liberation Sans/Mono als open lettertype.

De look komt uit twee lagen:

| Laag | Pad | Functie |
|---|---|---|
| Systeemstandaarden | `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/` | gelden voor elke gebruiker zonder eigen configuratie |
| Nieuwe gebruikers | `/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/` | wordt door Calamares naar de nieuwe home gekopieerd |

Een gebruiker die later met `useradd -m` of de gebruikersinstellingen wordt
aangemaakt, krijgt dezelfde bestanden via `/etc/skel`. Bestaande
gebruikerskeuzes worden niet overschreven.

## Btrfs, snapshots en rollback

LinuxBeOS maakt deze subvolumes:

| Subvolume | Mountpoint |
|---|---|
| `@` | `/` |
| `@home` | `/home` |
| `@snapshots` | `/.snapshots` |
| `@var_log` | `/var/log` |
| `@var_cache` | `/var/cache` |
| `@swap` | `/swap` (alleen bij een swapfile) |

Snapper maakt elk uur een tijdlijn-snapshot van `@` en rond
pakketbeheer. Een snapshot verschijnt als read-only entry in het GRUB-menu.

### Terugrollen

1. Herstart en kies in GRUB **LinuxBeOS snapshot &lt;nummer&gt; - ...**.
2. Log in en controleer de toestand.
3. Voer `sudo linuxbeos-rollback <nummer>` uit.
4. Herstart; het systeem start weer van `@`. `/home` blijft behouden.

De volledige procedure, inclusief rollback vanaf de live-ISO, staat in
[btrfs-layout.md](btrfs-layout.md).

## Handmatige installatie testen

De geautomatiseerde acceptatietest doorloopt dezelfde stappen zonder
toetsenbord of muis:

```sh
tests/test-install-uefi.sh
tests/test-install-bios.sh
```

De test installeert op een lege qcow2-schijf, boot het doel systeem, maakt
een snapshot, boot vanaf de snapshot, voert een rollback uit en controleert
dat `/home` bewaard is. Zie [calamares.md](calamares.md) voor de markers.

## Problemen oplossen

- Start de installer niet: controleer of de live-sessie actief is en of
  `sudo` werkt. Zie [troubleshooting.md](troubleshooting.md).
- Blijft GRUB na de installatie in het live-menu hangen: verwijder de
  USB-stick of ontkoppel de ISO en kies de schijf als eerste bootoptie.
- Ontbreekt het thema na inloggen: controleer
  `xfconf-query -c xfwm4 -p /general/theme` en de mappen onder
  `/usr/share/themes/LinuxBeOS`.

## Licentie en merken

LinuxBeOS is een onafhankelijk project. De vormgeving is vanaf nul gemaakt
en valt onder de MIT-licentie in `desktop/LICENSE`. Er zijn geen BeOS-,
Be Inc.- of Haiku-bestanden of handelsmerken overgenomen; zie
`desktop/NOTICE.md`.
