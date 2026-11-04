# Ontwikkelvoortgang LinuxBeOS

Laatst bijgewerkt: 2026-11-04

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
| 1 | Calamares standaardinstallatie (ext4) | TODO |
| 2 | Btrfs + subvolumes + snapshots | TODO |
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
