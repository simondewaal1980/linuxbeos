# Probleemoplossing

## Host

### `/dev/kvm` niet toegankelijk

```
FOUT: /dev/kvm is niet toegankelijk
```

Voeg de gebruiker toe aan de `kvm`-groep en log opnieuw in:

```sh
sudo usermod -aG kvm "$USER"
```

Of regel een ACL (zoals op de huidige host):

```sh
sudo setfacl -m u:"$USER":rw /dev/kvm
```

### Poort 2222 is bezet

Kies een andere poort in `config/project.conf`:

```sh
BUILD_VM_SSH_PORT="2223"
```

En pas eventueel de SSH-hints in de documentatie aan.

### Build-VM start niet of blijft offline

```sh
scripts/01-create-build-vm.sh --log
```

Bekijk `.build/vm/serial.log` en `.build/vm/serial.log.prev`. Vaak is het
cloud-image nog niet gedownload of is de host zonder netwerk.

Als de VM volledig in de war is:

```sh
scripts/01-create-build-vm.sh --recreate
```

Dit maakt een nieuwe overlay en seed-ISO; het basisimage blijft in
`.build/cache/`.

### Cloud-init hangt of is mislukt

```sh
scripts/01-create-build-vm.sh --status
ssh -p 2222 -i .build/vm/id_ed25519 builder@127.0.0.1 \
  'cloud-init status --long; sudo tail -n 100 /var/log/cloud-init-output.log'
```

Controleer of de Sid-mirror bereikbaar is. Bij een kapotte pakketversie kan
een nieuwe cloud-image of een snapshot-mirror nodig zijn.

## Build

### `lb build` mislukt

De volledige uitvoer staat in:

- host: `.build/lb-build.out`
- VM: `/home/builder/linuxbeos-build/lb-build.log`

Veelvoorkomende oorzaken:

- **Tijdelijk kapotte Sid-pakketten**: probeer opnieuw of pin via
  `snapshot.debian.org`.
- **Ontbrekende firmware-pakketten**: controleer de pakketnamen in
  `build/live-build/config/package-lists/desktop.list.chroot`.
- **GRUB EFI/BIOS**: Debian Sid's live-build moet `--bootloaders` ondersteunen.
  Controleer met `lb config --help | grep bootloaders` in de VM.
- **`insmod efi_uga` / `file not found` bij UEFI**: GRUB 2.14 levert deze module
  niet meer. Zorg dat `build/live-build/config/bootloaders/grub-pc/config.cfg`
  aanwezig is; dat bestand vervangt het live-build-sjabloon.
- **GRUB-menu wacht oneindig**: de override moet `set timeout=3` bevatten.
- **`network-manager-gnome` heeft geen kandidaat**: gebruik in Sid
  `network-manager-applet`.
- **Schijf vol in de VM**: controleer `df -h /` in de VM; de overlay is 40 GiB.

### Build is niet schoon

`scripts/10-build-iso.sh` bouwt standaard schoon. Met `--keep-workdir` wordt
de bestaande map hergebruikt; gebruik dat alleen voor snelle iteraties.

## Testen

### Geen `LINUXBEOS_SMOKE`-regel

Bekijk `tests/vm/<mode>/serial.log`. Zoek naar:

- GRUB-menu en kernelstart
- `Reached target graphical.target`
- `lightdm`
- fouten van NetworkManager

Mogelijke oorzaken:

- LightDM start geen XFCE-sessie (controleer `user-session=xfce` en de
  LightDM-configuratie in de ISO).
- NetworkManager krijgt geen DHCP-adres (QEMU user-networking).
- De live-gebruiker kon niet naar `/dev/ttyS0` schrijven; controleer de
  sudoers-regel in de ISO.

Met `--gui` kun je interactief inloggen en de desktop bekijken.

### UEFI boot niet, BIOS wel

Controleer of `ovmf` is geïnstalleerd en of `tests/vm/uefi/OVMF_VARS.fd`
bestaat. De OVMF-code wordt read-only gemount; de variabelen worden per test
gekopieerd.

### Test duurt lang

De eerste boot kan enkele minuten duren. Verhoog de timeout:

```sh
tests/test-uefi.sh --timeout 900
```

Zonder KVM valt de test terug op TCG; dat is erg traag. Zorg dat
`/dev/kvm` toegankelijk is.

### Installatietest stopt zonder `LINUXBEOS_AUTOINSTALL start`

De autoinstall-hulp draait alleen als:

- de live-omgeving actief is (`/run/live` bestaat);
- het SMBIOS-seriënnummer `LINUXBEOS-AUTOINSTALL` is (alleen leesbaar met
  sudo);
- de Xfce-sessie en `DISPLAY` beschikbaar zijn.

Bekijk `tests/vm/install-<mode>/install-serial.log` en
`/tmp/linuxbeos-autoinstall.log` in de live-sessie. De test faalt bewust
binnen ongeveer vijf minuten als de startmarkering ontbreekt; wachten op
`done` heeft dan geen zin.

### Calamares start wel maar de installatie blijft hangen

Controleer in het seriële log of de markering
`LINUXBEOS_AUTOINSTALL installing` verschijnt. Blijft die uit, dan is de
Xdotool-besturing niet door de pagina's gekomen. Start de test met `--keep`
en bekijk `install-failed.png`. Controleer ook of `xdotool` en
`x11-xserver-utils` in de ISO zitten.

Als Calamares een foutdialoog toont, blijft het proces wachten tot de
timeout. De laatste regels van het seriële log bevatten meestal de
Calamares-foutmelding; het volledige Calamares-log staat in de live-sessie
onder `/root/.cache/Calamares/` (of in het debugvenster).

## Btrfs, Snapper en rollback

### `The config 'root' does not exist` bij `snapper`

Debian-Snapper leest de lijst configuraties uit
`/etc/default/snapper`. Controleer:

```sh
grep SNAPPER_CONFIGS /etc/default/snapper   # moet "root" bevatten
sudo systemctl restart snapperd
sudo snapper -c root list
```

De build zet dit automatisch; op een handmatig gebouwd systeem moet de regel
`SNAPPER_CONFIGS="root"` aanwezig zijn.

### Geen `LinuxBeOS snapshot ...`-entry in GRUB

Controleer of de generator draait en of `/boot` in de root-subvolume zit:

```sh
ls -l /etc/grub.d/41_snapshots-btrfs
/etc/grub.d/41_snapshots-btrfs
findmnt -T /boot
sudo /usr/local/sbin/linuxbeos-update-grub
grep linuxbeos-snapshot /boot/grub/grub.cfg
```

Het log van de laatste regeneratie staat in
`/var/log/linuxbeos-update-grub.log`. Een aparte `/boot`-partitie wordt in
deze fase niet ondersteund.

### Rollback geweigerd

`linuxbeos-rollback` weigert te draaien vanuit de actieve `@`. Start eerst
de gewenste snapshot vanuit GRUB of gebruik de live-ISO:

```sh
sudo linuxbeos-rollback --device /dev/sda2 <nummer>
```

### Test stopt na `LINUXBEOS_BTRFS_step ...`

Bekijk `tests/vm/install-<mode>/boot-serial.log`. De stapmarkeringen tonen
waar de testhulp is gebleven. Het volledige hulplog staat op het
geïnstalleerde systeem in `/var/log/linuxbeos/btrfs-test.log`; het
rollbacklog in `/var/log/linuxbeos/rollback.log`.

Als de VM na de eerste herstart stopt, controleer dan of de testharness
zonder `-no-reboot` draait. Die optie laat QEMU na een guest-reboot
termineren en is voor de driedelige Btrfs-test verwijderd.

## BeOS-thema (fase 3)

### De desktop blijft standaard Debian/Xfce

Controleer in de live-sessie:

```sh
xfconf-query -c xfwm4 -p /general/theme
xfconf-query -c xsettings -p /Net/ThemeName
xfconf-query -c xsettings -p /Net/IconThemeName
ls /usr/share/themes/LinuxBeOS /usr/share/icons/LinuxBeOS
```

Als de bestanden ontbreken, is de build niet goed klaargezet. Controleer in
de build-VM of `desktop/` en `overlays/` in `config/includes.chroot` staan.
Als de bestanden er wel zijn maar de waarden niet kloppen, heeft de
gebruiker een eigen xfconf-waarde; verwijder die of start met een schone
`~/.config/xfce4`.

### `LINUXBEOS_THEME fail ...` in het seriële log

De marker noemt de eerste afwijkingen, bijvoorbeeld
`wallpaper=missing` of `deskbar-position=...`. Bekijk in de live-sessie:

```sh
cat /tmp/linuxbeos-theme-ready      # bestaat alleen bij succes
xfconf-query -c xfce4-panel -l | sort
xfconf-query -c xfce4-desktop -l | grep last-image
```

- **wallpaper=missing**: `linuxbeos-theme-apply` draait vóór de controle en
  vult ontbrekende monitoren aan. Controleer of xfdesktop draait en of
  `/usr/share/backgrounds/linuxbeos/linuxbeos-wallpaper.png` bestaat.
- **deskbar-plugins**: het paneel heeft zijn standaardconfiguratie niet
  geladen. Controleer of `xfce4-panel.xml` in
  `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/` staat en of de gebruiker geen
  oud `~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml` heeft.
- **xfwm4/gtk/icons/cursor**: het thema staat niet op `LinuxBeOS`; controleer
  `xsettings.xml`, `xfwm4.xml` en de themamappen.

Voor diagnose kan de rooktest met `--skip-theme` worden gestart; de sessie
moet dan nog steeds `LINUXBEOS_SMOKE ...` halen.

### De titeltab is geel maar de titeltekst ontbreekt

De tab gebruikt `title-active-stretch`, dat pas vanaf xfwm4 4.20 wordt
geladen. Controleer de versie:

```sh
xfwm4 --version
```

Op Debian Sid hoort dit 4.20 of nieuwer te zijn. Bij een oudere versie is de
gedocumenteerde fallback actief; werk xfwm4 bij of accepteer dat de titeltekst
in dat geval niet wordt getekend.

### De cursor of de iconen zijn na een themawijziging niet zichtbaar

De build werkt de caches bij in `0300-theme.chroot`. Op een draaiend systeem:

```sh
sudo gtk-update-icon-cache -f -t /usr/share/icons/LinuxBeOS
xfce4-panel -r
xfwm4 --replace &
```

Meld je daarna opnieuw aan; sommige applicaties lezen het icoonthema alleen
bij het starten.

## Veiligheid

Alle scripts werken uitsluitend met qcow2-bestanden. Er worden nooit fysieke
schijven geopend of geformatteerd. Controleer bij twijfel altijd het pad in
`config/project.conf` en de gebruikte `qemu-img`-commando's.
