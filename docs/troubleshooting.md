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

## Veiligheid

Alle scripts werken uitsluitend met qcow2-bestanden. Er worden nooit fysieke
schijven geopend of geformatteerd. Controleer bij twijfel altijd het pad in
`config/project.conf` en de gebruikte `qemu-img`-commando's.
