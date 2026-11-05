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
| 3 | BeOS 5-thema op XFCE | GEREED |
| 4 | Volledige integratie en releasegate | GEREED |

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

## Fase 3 — BeOS 5-thema op XFCE

**Doel:** de live-sessie toont out-of-the-box de BeOS R5-look: vensters,
Deskbar, iconen, cursor en achtergrond.
**Nog niet:** integratie met de installer en het doelsysteem (fase 4).

### Checklist

| # | Onderdeel | Status |
|---|---|---|
| 1 | xfwm4-thema met gele titeltab, sluit- en zoomknop | GEREED |
| 2 | GTK2- en GTK3-thema met BeOS-grijstinten en vlakke widgets | GEREED |
| 3 | Deskbar rechtsboven (menu, vensterlijst, klok) via xfconf | GEREED |
| 4 | Eigen SVG-iconen, Xcursor-thema en achtergrond | GEREED |
| 5 | LightDM-greeter, terminalprofiel en lettertypekeuze | GEREED |
| 6 | Licenties en herkomst van alle assets vastgelegd | GEREED |
| 7 | Statische test op alle themabestanden, symlinks en XML | GEREED |
| 8 | Automatische themacontrole met `LINUXBEOS_THEME`-marker | GEREED |
| 9 | Rooktest UEFI en BIOS met themacontrole en screenshots | GEREED |
| 10 | Visuele checklist in `docs/theme.md` afgerond | GEREED |
| 11 | ZSH als standaardshell voor live- en installatiegebruikers | GEREED |
| 12 | ZSH-branding en git-herkenning via `vcs_info` | GEREED |
| 13 | `git`, `opencode` (vastgepind + SHA256) en Google Chrome in de ISO | GEREED |
| 14 | Sessiecontrole bewijst `shell=ok apps=ok` op UEFI én BIOS | GEREED |
| 15 | Donkere GTK2/GTK3-variant `LinuxBeOS-Dark` + `linuxbeos-theme-mode` | GEREED |
| 16 | Uitgebreide ZSH-prompt met status, looptijd, taken en klok | GEREED |

De onderdelen 15 en 16 zijn na de fase 4-release toegevoegd. De ISO is
opnieuw gebouwd (`46b87d4e…`, 1,7 GiB); de UEFI- én BIOS-rooktest bevestigen
`dark=ok` in de live-sessie. De donkere bestanden zitten aantoonbaar in de
ISO-squashfs en worden via `unpackfs` naar het doelsysteem gekopieerd. De
volledige installatie-/releasematrix is na deze aanvulling nog niet opnieuw
gedraaid.

Na een visuele controle bleek de Deskbar in donkere modus licht te blijven:
het paneel had een vaste BeOS-grijze achtergrond (`background-style=1`) die
niet met het GTK-thema meewisselde. De standaard is nu `background-style=0`
(themakleuren) en `linuxbeos-theme-mode` zet een oude vaste paneelkleur
terug naar themavolgending. Daarmee wordt de balk bij `LinuxBeOS-Dark`
donkergrijs; de gele titeltab, iconen en cursor blijven bewust ongewijzigd.
De ISO is opnieuw gebouwd (`b0fa6e58…`, 1,7 GiB); de UEFI- én BIOS-rooktest
slagen met `LINUXBEOS_THEME ok ... dark=ok shell=ok apps=ok`. De volledige
installatie-/releasematrix is na deze bugfix niet opnieuw gedraaid.

### Acceptatiecriteria

- [x] De live-sessie toont de BeOS-look zonder handmatige instellingen.
- [x] De rooktest op UEFI en BIOS schrijft `LINUXBEOS_THEME ok ...`.
- [x] De ZSH-prompt toont branding en git-status in repositories.
- [x] De ZSH-prompt toont exitstatus, looptijd van trage commando's,
  achtergrondtaken en een klok.
- [x] De donkere GTK-variant is aanwezig en met `linuxbeos-theme-mode`
  wisselbaar.
- [x] `git`, `opencode` en Google Chrome zijn aanwezig in de live-sessie.
- [x] De visuele checklist is afgerond en voorzien van screenshots.
- [x] Licenties en beperkingen zijn gedocumenteerd.

### Bewijs

| Controle | UEFI | BIOS |
|---|---|---|
| Sessiemarker | `LINUXBEOS_SMOKE session=xfce network=connected` | idem |
| Themmarker | `LINUXBEOS_THEME ok xfwm4=LinuxBeOS gtk=LinuxBeOS icons=LinuxBeOS cursor=LinuxBeOS deskbar=top-right wallpaper=ok skel=ok xdg=ok shell=ok apps=ok` | idem |
| Shell/software | `zsh` 5.9.2, `git` 2.55.0, `opencode` 1.19.5, Chrome 157.0.8103.38 | idem |
| Bureaublad | [phase3-live-uefi.png](screenshots/phase3-live-uefi.png) | [phase3-live-bios.png](screenshots/phase3-live-bios.png) |
| Vensters + Deskbar | [phase3-windows-uefi.png](screenshots/phase3-windows-uefi.png) | [phase3-windows-bios.png](screenshots/phase3-windows-bios.png) |
| Geïnstalleerd systeem | [phase3-installed-uefi.png](screenshots/phase3-installed-uefi.png) — `LINUXBEOS_THEME ok` in `boot-serial.log` | idem via dezelfde installatieketen (fase 2-test) |
| Testmap | `tests/vm/uefi/` | `tests/vm/bios/` |

| Buildgegeven | Waarde |
|---|---|
| ISO | `dist/linuxbeos-0.1-amd64.iso` |
| SHA256 | `45e52a21a0e4fe792f8e5acd22c183b98dff32c95f1128eabcd775f11eb3b64c` |
| Grootte | 1,7 GiB |
| Kernel | `7.2.15+deb14-amd64` |
| xfwm4 | 4.20.0 (Debian Sid) |
| Thema | `LinuxBeOS` (xfwm4 + GTK2 + GTK3) |
| Iconen/cursor | `LinuxBeOS` |
| Lettertypen | Liberation Sans / Liberation Mono |
| Shell | ZSH 5.9.2-1+b1 (root: bash) |
| Extra software | git 2.55.0-1, opencode 1.19.5, Google Chrome 157.0.8103.38-1 |

De live-sessie start met autologin en laadt de xfconf-standaardwaarden uit
`/etc/xdg`. De themacontrole bevestigt de runtimewaarden en schrijft de
seriële marker. De visuele checklist en de volledige beschrijving staan in
[docs/theme.md](theme.md).

### Ontwerp in het kort

- **xfwm4:** volle-brede gele tab via `title-active-stretch`, knoppen
  `C|M`, grijze inactieve tab, donkere tekst.
- **GTK:** `#d6d6d6`-achtergrond, rechte randen, 1px-bevel, gele actieve
  notebooktab, donkerblauwe terminal.
- **Deskbar:** paneel `p=2` (rechtsboven), 34% breed, met
  `applicationsmenu`, `tasklist` en `clock`; de achtergrond volgt het actieve
  GTK-thema (licht of donker).
- **Assets:** eigen SVG-iconen met Adwaita-fallback, eigen Xcursor, eigen
  1920×1080-achtergrond, Liberation Sans/Mono.
- **Controle:** `linuxbeos-theme-check` schrijft een seriële marker;
  `tests/static/check-config.sh` controleert de configuratie statisch.

### Aandachtspunten

- De BeOS-tab wordt nagebootst met de xfwm4-themaengine. Een perfecte
  tabgeometrie en native zoomgedrag zijn niet mogelijk; dit staat
  gedocumenteerd in `docs/theme.md`.
- `title-active-stretch` vereist xfwm4 4.20 (Debian Sid). Oudere versies
  vallen terug op de losse titelstukken.
- De assets zijn vanaf nul getekend. Er zijn geen BeOS-, Be Inc.- of
  Haiku-bestanden of merken overgenomen; zie `desktop/NOTICE.md`.
- Het thema wordt door `unpackfs` automatisch in het doelsysteem geplaatst.
  De expliciete integratie en de testmatrix daarvan horen bij fase 4.

## Fase 4 — Volledige integratie en releasegate

**Doel:** één releasecommando, een BeOS-gestijlde installer, dezelfde look op
het doelsysteem en een volledige testmatrix als releasegate.

### Checklist

| # | Onderdeel | Status |
|---|---|---|
| 1 | Calamares-branding volledig in BeOS-stijl (kleuren, logo, slideshow met pijlers) | GEREED |
| 2 | Thema op het doelsysteem via `/etc/skel` + xfconf-standaarden, inclusief Deskbar | GEREED |
| 3 | Eén commando: hostcheck → build → ISO → SHA256 → automatische rooktest | GEREED |
| 4 | Releasematrix: UEFI/BIOS × Btrfs-installatie × thema × snapshot/rollback | GEREED |
| 5 | README, build-guide, installatiehandleiding, btrfs-layout, troubleshooting en releaseproces | GEREED |
| 6 | Bewijs vastleggen in `dist/release-matrix.txt` en dit document | GEREED |

### Acceptatiecriteria

- [x] Van schone checkout tot geteste ISO met één script.
- [x] Geïnstalleerd systeem heeft dezelfde look als de live-sessie.
- [x] De hele testmatrix is groen.

### Bewijs

De volledige matrix draaide op de fase 4-ISO en schreef 32 controles, allemaal
geslaagd:

| Controle | UEFI | BIOS |
|---|---|---|
| Live-sessie + netwerk | `LINUXBEOS_SMOKE session=xfce network=connected` | idem |
| Thema in de live-sessie | `LINUXBEOS_THEME ok ... deskbar=top-right wallpaper=ok skel=ok xdg=ok` | idem |
| Installatie | `LINUXBEOS_AUTOINSTALL done` | idem |
| Zelfstandige boot | `LINUXBEOS_INSTALLED_READY hostname=linuxbeos-standardpc` | idem |
| Thema op het doel | `LINUXBEOS_THEME ok ... skel=ok xdg=ok` | idem |
| Btrfs-layout | `LINUXBEOS_BTRFS_LAYOUT ok subvolumes=@,@home,@snapshots,@var_log,@var_cache,@swap fstab=subvol,compress=zstd,noatime` | idem |
| Snapper-snapshot | `LINUXBEOS_BTRFS_SNAPSHOT ok number=2` | idem |
| Snapshot in GRUB | `LINUXBEOS_BTRFS_GRUB ok number=2` | idem |
| Boot vanaf snapshot | `LINUXBEOS_BTRFS_SNAPSHOT_BOOT ok number=2 subvol=/@snapshots/2/snapshot` | idem |
| Rollback + `/home` | `LINUXBEOS_BTRFS_ROLLBACK ok number=2 marker=original home=preserved` | idem |
| Rollbacktest afgerond | `LINUXBEOS_BTRFS_TEST done` | idem |
| Geïnstalleerd = live-look | PASS | PASS |
| Screenshot live | [phase4-live-uefi.png](screenshots/phase4-live-uefi.png) | [phase4-live-bios.png](screenshots/phase4-live-bios.png) |
| Vensters + Deskbar | [phase4-windows-uefi.png](screenshots/phase4-windows-uefi.png) | [phase4-windows-bios.png](screenshots/phase4-windows-bios.png) |
| Screenshot geïnstalleerd | [phase4-installed-uefi.png](screenshots/phase4-installed-uefi.png) | [phase4-installed-bios.png](screenshots/phase4-installed-bios.png) |
| Testmap | `tests/vm/install-uefi/` | `tests/vm/install-bios/` |

| Buildgegeven | Waarde |
|---|---|
| ISO | `dist/linuxbeos-0.1-amd64.iso` |
| SHA256 | `6be89f9de7dd2bb4d35a2e29cdab27d98ffc3889f2198a518975906b63eba856` |
| Grootte | 1,5 GiB |
| Kernel | `7.2.15+deb14-amd64` |
| Calamares | 3.4.3 (Debian Sid) |
| live-build | `20250814` |
| Releasecommando | `scripts/20-build-release.sh --full` |
| Matrixrapport | `dist/release-matrix.txt` (32 controles, 0 overgeslagen) |

**Schone checkout:** een kopie zonder `.git`, `.build`, `dist` en
`tests/vm` is met één commando gebouwd en getest:

```sh
LINUXBEOS_BUILD_DIR=/home/simon/Projecten/Linuxdist/.build \
LINUXBEOS_DIST_DIR=/home/simon/Projecten/linuxbeos-phase4-clean-dist \
LINUXBEOS_TEST_VM_DIR=/home/simon/Projecten/linuxbeos-phase4-clean-tests \
  scripts/20-build-release.sh --full
```

Resultaat: ISO `b9341a1532de935785de09a9461f84331fcaa452bec1b37c6ac2360cd52401b3`,
hostcontrole geslaagd, UEFI/BIOS-rooktest geslaagd en de volledige matrix
geslaagd (32 controles, 0 overgeslagen). De build gebruikte de gedeelde
build-VM en pakketcache.

### Aandachtspunten

- De standaard `make release` doet hostcheck, build en rooktesten; alleen
  `make release-full` (of `--full`) is de volledige releasegate met
  Btrfs-installatie en rollback.
- De themacontrole start via XDG-autostart en kan enkele seconden later zijn
  dan de Btrfs-testhulp. De installatietest wacht daarom maximaal 180 seconden
  op `LINUXBEOS_THEME ok` in plaats van direct te falen.
- De installatietest bewaart het thema-bewijs in `boot-result.txt` en het
  volledige seriële log; de matrix leest dezelfde markers opnieuw.
- De releasegate is streng: een ontbrekende `skel=ok`, `xdg=ok` of
  `home=preserved` marker laat de matrix falen.

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
| 2026-11-05 | Thema-assets vanaf nul getekend, MIT-licentie | Geen BeOS/Haiku-merken of -bestanden overnemen; herkomst en licentie staan in `desktop/NOTICE.md`. |
| 2026-11-05 | Gele tab via `title-active-stretch` (xfwm4 4.20) | De stretch-afbeelding geeft de volle-brede BeOS-tab; losse titelstukken en XPM blijven als fallback aanwezig. |
| 2026-11-05 | Knoppenindeling `C|M` (sluiten links, zoom rechts) | Komt overeen met de BeOS-tab; minimaliseren gebeurt via de vensterlijst in de Deskbar. |
| 2026-11-05 | Deskbar als xfce4-panel op `p=2`, 34% breed | Rechtsboven, compact, met menu, vensterlijst en klok, zonder struts zodat hij als klassieke Deskbar over vensters ligt. |
| 2026-11-05 | Liberation Sans/Mono in plaats van Swiss 721 | Open SIL OFL-alternatief dat in Debian Sid beschikbaar is en geen extra niet-vrije download vereist. |
| 2026-11-05 | Themacontrole als seriële marker in de rooktest | De acceptatie is machinaal aantoonbaar; `--skip-theme` blijft beschikbaar voor diagnose. |
| 2026-11-05 | Achtergrond per monitor aangevuld door `linuxbeos-theme-apply` | xfdesktop gebruikt connector-namen; de helper vult alleen ontbrekende waarden aan en respecteert gebruikerskeuzes. |
| 2026-11-05 | Calamares-branding in BeOS-grijs/geel met een slideshow van de pijlers | De installer moet dezelfde identiteit als de desktop uitstralen; geen externe afbeeldingen of merken. |
| 2026-11-05 | xfconf-standaarden ook naar `/etc/skel/.config/xfce4/xfconf/` | Nieuwe gebruikers krijgen de Deskbar en het thema direct; `/etc/xdg` blijft de systeembron. |
| 2026-11-05 | `scripts/20-build-release.sh` als één releasecommando | Hostcheck, build, SHA256 en rooktesten horen bij elkaar; `--full` voegt de installatiematrix toe. |
| 2026-11-05 | `tests/release-matrix.sh` met markervalidatie als releasegate | De acceptatie is machinaal aantoonbaar en een ontbrekende marker blokkeert de release. |
| 2026-11-05 | Installatietest wacht 180 s op de themamarker | De XDG-autostartthemacontrole kan later starten dan de Btrfs-hulp; een vaste wachttijd voorkomt een race. |
| 2026-11-05 | Deskbar volgt het GTK-thema (`background-style=0`) | Een vaste lichte paneelkleur bleef in `LinuxBeOS-Dark` staan; `linuxbeos-theme-mode` zet oude vaste paneelkleuren terug naar themavolgending. |
| 2026-11-05 | ISO opnieuw gebouwd na de Deskbar-darkfix (`b0fa6e58…`, 1,7 GiB) | De UEFI- en BIOS-rooktest slagen; de donkere modus is in een VM visueel gecontroleerd met een donkere Deskbar. |

## Aandachtspunten voor latere fasen

1. **Definitieve distronaam:** LinuxBeOS is een werktitel. Wijzigen op één plek
   (`config/project.conf`) en daarna ISO/branding opnieuw genereren.
2. **Pinnen van Debian Sid:** de cloud-image en pakketten zijn momenteel
   "latest". Voor strikte reproduceerbaarheid later `snapshot.debian.org`
   en een vastgepinde cloud-image-datum gebruiken.
3. **Buildtijd:** de eerste build duurt circa 15-20 minuten; latere builds
   hergebruiken de live-build-pakketcache in de VM.
4. **Live-identiteit:** live-sessie en doelsysteem gebruiken het LinuxBeOS-
   thema, de Deskbar en de eigen achtergrond. De definitieve distronaam en
   eventuele gebruikersnaam blijven toekomstig werk.
5. **Thema op het doelsysteem:** `unpackfs` neemt de themabestanden en
   `/etc/xdg`-standaardwaarden mee; de build vult daarnaast `/etc/skel`.
   De fase 4-matrix bewijst dat een nieuwe gebruiker dezelfde look krijgt.
   Bestaande gebruikerskeuzes worden niet overschreven.
6. **Secure Boot:** de ISO is nog steeds unsigned. `shim-signed` +
   `grub-efi-amd64-signed` toevoegen is toekomstig werk en nog niet getest.
7. **Oude root opruimen:** na een rollback blijft `@.broken-<tijdstip>` staan.
   Dat is bewust (veilig terugvallen) maar moet door de gebruiker of een
   toekomstig opruimscript worden verwijderd.
8. **Snapshotgenerator:** de eigen `41_snapshots-btrfs` ondersteunt geen
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
| 2026-11-05 | Fase 3 gestart: xfwm4-, GTK2/GTK3-, icoon- en cursorthema, Deskbar en achtergrond toegevoegd. |
| 2026-11-05 | Eigen renderscript `desktop/tools/generate-assets.py` voor xfwm4-afbeeldingen, Xcursor en achtergronden. |
| 2026-11-05 | xfconf-standaardwaarden, LightDM-greeter en terminalprofiel toegevoegd; themacontrole schrijft `LINUXBEOS_THEME`. |
| 2026-11-05 | Statische controle uitgebreid met themabestanden, symlinks, xfconf-waarden en XML-syntax. |
| 2026-11-05 | Eerste thema-ISO getest: marker geslaagd, maar paneel toonde alleen menu en analoge klok; desktoppictogrammen stonden uit. |
| 2026-11-05 | xfce4-desktop gecorrigeerd: `desktop-icons/style=2` en `file-icons/show-*`; klok op digitale modus (2); tasklist `expand=true`. |
| 2026-11-05 | Tweede test bevestigde desktoppictogrammen, digitale klok en vensterlijst; vensterscherm toonde de gele actieve tab en grijze inactieve tab. |
| 2026-11-05 | Testhulp `linuxbeos-theme-demo` toegevoegd (alleen actief bij SMBIOS-seriënummer `LINUXBEOS-THEME-DEMO`) voor de vensterscreenshot. |
| 2026-11-05 | Definitieve fase 3-ISO gebouwd (`95515c46…`); UEFI- en BIOS-rooktest met `LINUXBEOS_THEME ok` geslaagd. |
| 2026-11-05 | Screenshots toegevoegd: `phase3-live-{uefi,bios}.png` en `phase3-windows-{uefi,bios}.png`; visuele checklist afgerond. |
| 2026-11-05 | UEFI-installatietest herhaald op de fase 3-ISO: Btrfs-rollback geslaagd en het geïnstalleerde systeem schrijft `LINUXBEOS_THEME ok`. |
| 2026-11-05 | Screenshot geïnstalleerd systeem toegevoegd als `phase3-installed-uefi.png`. |
| 2026-11-05 | Fase 4 gestart: Calamares-branding in BeOS-palet, bijgewerkte slideshow en logo's. |
| 2026-11-05 | Thema-integratie uitgebreid: build kopieert xfconf-standaarden naar `/etc/skel`; themacontrole bewijst `skel=ok xdg=ok`. |
| 2026-11-05 | `scripts/20-build-release.sh` toegevoegd: hostcheck → ISO → SHA256 → automatische rooktest. |
| 2026-11-05 | `tests/release-matrix.sh` toegevoegd als releasegate voor UEFI/BIOS, Btrfs, thema en rollback. |
| 2026-11-05 | Documentatie uitgebreid met installatiehandleiding, releaseproces en fase 4-aandachtspunten. |
| 2026-11-05 | Eerste fase 4-matrixrun: alle inhoudelijke markers groen, maar `run-install-test.sh` eindigde met status 1 door een `(( KEEP )) && ...`-regel; opgelost met een expliciete `exit 0`. |
| 2026-11-05 | Tweede matrixrun: themacontrole op het doel kon enkele seconden na de Btrfs-hulp starten; de installatietest wacht nu maximaal 180 s op `LINUXBEOS_THEME ok` in plaats van direct te falen. |
| 2026-11-05 | Fase 4-ISO gebouwd (`6be89f9d…`, 1,5 GiB) en de volledige releasematrix geslaagd: 32 controles, 0 overgeslagen, UEFI én BIOS. |
| 2026-11-05 | Screenshots toegevoegd: `phase4-live-{uefi,bios}.png`, `phase4-windows-{uefi,bios}.png` en `phase4-installed-{uefi,bios}.png`. |
| 2026-11-05 | Schone-checkouttest geslaagd met één commando (`scripts/20-build-release.sh --full`); clean-build-ISO `b9341a15…`, hostcheck, rooktesten en matrix allemaal groen. |
| 2026-11-05 | Fase 4 afgerond; alle acceptatiecriteria en de volledige testmatrix zijn aangetoond. |
| 2026-11-05 | Fase 3 uitgebreid met ZSH (branding + git-prompt), git, opencode 1.19.5 en Google Chrome stable. |
| 2026-11-05 | `DSHELL` in `/etc/adduser.conf` geactiveerd zodat de live-gebruiker ook echt ZSH krijgt; Calamares zet `user.shell: /bin/zsh`. |
| 2026-11-05 | ISO opnieuw gebouwd (`45e52a21…`, 1,7 GiB); UEFI- en BIOS-rooktest geslaagd met `shell=ok apps=ok`. |
| 2026-11-05 | Donkere GTK2/GTK3-variant `LinuxBeOS-Dark` toegevoegd met `linuxbeos-theme-mode`; buildscript, themacontrole en releasematrix kennen `dark=ok`. |
| 2026-11-05 | ZSH-prompt uitgebreid met een statusregel (exitcode, looptijd, achtergrondtaken), een bescheiden klok, terminaltitel en snellere offline completion. |
| 2026-11-05 | ISO opnieuw gebouwd na de donkere GTK-variant en ZSH-uitbreiding (`46b87d4e…`, 1,7 GiB). |
| 2026-11-05 | UEFI- en BIOS-rooktest geslaagd met `LINUXBEOS_THEME ok ... dark=ok shell=ok apps=ok`. |
