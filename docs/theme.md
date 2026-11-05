# BeOS 5-thema op XFCE (fase 3)

## Doel

De live-sessie moet zonder handmatige instellingen een herkenbare BeOS
R5-desktop tonen: een gele titeltab, vlakke grijze widgets, een compacte
Deskbar rechtsboven, eigen pictogrammen, een BeOS-achtige cursor en een
blauwe achtergrond. De installer en het doelsysteem blijven in deze fase
buiten beschouwing; die integratie volgt in fase 4.

## Bestandsindeling

| Bron in de repo | Doel in de ISO |
|---|---|
| `desktop/xfwm4/` | `/usr/share/themes/LinuxBeOS/xfwm4/` |
| `desktop/gtk/gtk-2.0/` en `gtk-3.0/` | `/usr/share/themes/LinuxBeOS/` |
| `desktop/icons/LinuxBeOS/` | `/usr/share/icons/LinuxBeOS/` |
| `desktop/cursors/LinuxBeOS/` | `/usr/share/icons/LinuxBeOS/` (cursor-thema) |
| `desktop/backgrounds/` | `/usr/share/backgrounds/linuxbeos/` |
| `overlays/etc/xdg/xfce4/xfconf/` | xfconf-standaardwaarden voor alle gebruikers |
| `overlays/etc/lightdm/lightdm-gtk-greeter.conf.d/` | LightDM-greeterconfiguratie |
| `overlays/usr/local/bin/linuxbeos-theme-*` | thema toepassen en controleren |
| `overlays/etc/xdg/autostart/` | automatisch toepassen/controleren bij inloggen |

`scripts/11-build-iso-in-vm.sh` kopieert deze mappen naar de live-build
includes. De chroot-hook `0300-theme.chroot` werkt daarna de icooncache,
desktop-database en fontcache bij.

## Vensterdecoratie (xfwm4)

- Gele titeltab over de volle breedte, met een lichte bovenrand en donkere
  onderrand.
- Sluitknop links (zwarte X) en zoomknop rechts (zwart vierkant), beide in de
  tab. Dit is de BeOS-indeling `C|M`.
- Inactieve vensters krijgen een grijze tab en grijze symbolen.
- De tab gebruikt `title-active-stretch`/`title-inactive-stretch`, een
  xfwm4 4.20-functie. De losse `title-1…5`-PNG's en de XPM-varianten blijven
  aanwezig als fallback voor oudere xfwm4-versies.
- De windowmanager gebruikt geen compositing, zodat de vlakke BeOS-look
  behouden blijft en de VM geen GL nodig heeft.

**Bekende beperking:** vóór xfwm4 4.20 wordt de stretch-afbeelding niet
geladen. De tab valt dan terug op de losse titelstukken; de titeltekst kan
ontbreken. Debian Sid levert xfwm4 4.20, dus de ondersteunde build voldoet.
Perfecte BeOS-tabgeometrie (schuine tabvoet, native zoomgedrag) is met de
xfwm4-themaengine niet mogelijk; dit is bewust gedocumenteerd in plaats van
met een third-party windowmanager opgelost.

## GTK2 en GTK3

- Kleuren: achtergrond `#d6d6d6`, tekst `#101010`, selectie `#3366cc`,
  actieve tab `#f5e64b`.
- Rechte hoeken, 1px-donkereranden en een lichte/donkere bevel in plaats van
  gradients of schaduwen.
- Menu's, notebooks, schuifbalken, knoppen, invoervelden en panelen hebben
  aparte regels in `desktop/gtk/gtk-3.0/gtk.css`; `gtk-2.0/gtkrc` bevat
  dezelfde kleuren voor oudere applicaties.
- De actieve notebooktab is geel, net als de venstertab.

## Deskbar

`overlays/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml`
configureert één horizontaal paneel rechtsboven:

1. `applicationsmenu` met het LinuxBeOS-logo als menuknop;
2. `tasklist` met tekstlabels, zonder grouping, als vensterlijst; de
   vensterlijst heeft `expand=true` en vult de ruimte tussen menu en klok;
3. `clock` in digitale modus met `%a %H:%M`.

Het paneel heeft een vaste lengte van 34%, staat op `p=2` (rechtsboven),
gebruikt de BeOS-grijze achtergrond en reserveert geen struts. Zo gedraagt
het zich als de klassieke Deskbar die over vensters heen ligt.

## Iconen, cursor, achtergrond en font

- Iconen: eigen SVG-set in `desktop/icons/LinuxBeOS/scalable/`, met
  aliassen voor Thunar, Firefox, xfce4-terminal, Calamares en de
  standaardplaatsen. Het thema erft `Adwaita` en `hicolor` voor alles wat
  niet is getekend.
- Cursor: eigen Xcursor-thema met een zwarte pijl met witte rand, gegenereerd
  uit `desktop/tools/generate-assets.py`.
- Achtergrond: eigen 1920×1080-PNG met een blauw verloop, subtiele diagonale
  lijnen en een gele LinuxBeOS-tab. Geen BeOS- of Haiku-beeldmateriaal.
- Font: Liberation Sans (SIL OFL) als open alternatief voor de BeOS-systeemfont
  Swiss 721; de terminal gebruikt Liberation Mono.
- LightDM gebruikt dezelfde achtergrond, hetzelfde thema en dezelfde cursor.
- De terminal start met een donkerblauwe achtergrond, gele cursor en zonder
  menubalk.

## Automatische controle

`linuxbeos-theme-check` start via XDG-autostart en controleert:

- `xfwm4/general/theme`, `xsettings/Net/ThemeName`,
  `Net/IconThemeName` en `Gtk/CursorThemeName`;
- de Deskbarpositie (`p=2`) en de drie panelplugins;
- of ten minste één monitor de LinuxBeOS-achtergrond gebruikt;
- of de belangrijkste themabestanden in het systeem staan.

Bij succes schrijft het script naar de seriële console:

```
LINUXBEOS_THEME ok xfwm4=LinuxBeOS gtk=LinuxBeOS icons=LinuxBeOS cursor=LinuxBeOS deskbar=top-right wallpaper=ok
```

`tests/lib/run-vm-test.sh` wacht op deze regel naast de bestaande
`LINUXBEOS_SMOKE`-regel. Met `--skip-theme` kan een sessie zonder
themacontrole worden getest bij het opsporen van regressies.

`linuxbeos-theme-apply` vult alleen ontbrekende of ongeldige
achtergrondinstellingen aan. Het overschrijft nooit een bewuste
gebruikerskeuze; daarmee blijft het script ook bruikbaar op het
geïnstalleerde systeem in fase 4.

Voor de screenshots in de visuele checklist start de rooktest de VM met het
SMBIOS-seriënnummer `LINUXBEOS-THEME-DEMO`. Alleen dan opent
`linuxbeos-theme-demo` een terminal en Thunar, zodat de vensterdecoratie en
de Deskbar met vensterlijst op de screenshot zichtbaar zijn. In een normale
live-sessie en op het doelsysteem doet dit script niets. De test maakt twee
opnamen: `screenshot.png` (bureaublad met pictogrammen) en
`screenshot-windows.png` (geopende vensters). Met `--no-demo` wordt alleen
het bureaublad opgenomen.

## Statische controle

`tests/static/check-config.sh` controleert onder meer:

- de vereiste themabestanden en uitvoerbare scripts;
- `full_width_title=true` en `button_layout=C|M`;
- de geselecteerde xfconf-waarden voor thema, iconen, cursor en font;
- de Deskbarpositie en de drie plugins;
- de achtergrondverwijzing;
- dat de buildscript `desktop/` en `overlays/` meeneemt;
- dat alle icoonsymlinks naar bestaande bestanden wijzen;
- de XML-syntax van de xfconf-bestanden (met `xmllint`).

## Visuele checklist in de VM

De checklist wordt na de UEFI- en BIOS-rooktest met screenshots afgevinkt.
Referenties zijn de kenmerken van BeOS R5, niet overgenomen beeldbestanden.

| # | Controle | Status |
|---|---|---|
| 1 | Actief venster heeft een gele tab over de volle breedte | GEREED — Terminal in de vensterscreenshot |
| 2 | Sluitknop links en zoomknop rechts zijn zichtbaar | GEREED — zichtbaar in actief en inactief venster |
| 3 | Inactief venster heeft een grijze tab | GEREED — Thunar in de vensterscreenshot |
| 4 | GTK-widgets zijn vlak, grijs en hebben rechte hoeken | GEREED — menu's, knoppen en invoervelden |
| 5 | Actieve notebooktab is geel | GEREED (statisch) — CSS-regel aanwezig en CSS parseert; niet in de automatische demo geopend |
| 6 | Deskbar staat rechtsboven met logo, vensterlijst en klok | GEREED — LB-menu, vensterknoppen en digitale klok |
| 7 | Bureaublad gebruikt de LinuxBeOS-achtergrond | GEREED |
| 8 | Bureaublad en Thunar tonen de eigen pictogrammen | GEREED — Home, File System, Trash, Install LinuxBeOS |
| 9 | Cursor is de eigen zwart-witte pijl | GEREED — zichtbaar in beide screenshots |
| 10 | Terminal gebruikt Liberation Mono en het donkere profiel | GEREED — zwarte achtergrond, gele cursor, monospace |
| 11 | LightDM toont de LinuxBeOS-achtergrond en het thema | GEREED (configuratie) — autologin verbergt de greeter in de standaardtests |
| 12 | Screenshots opgenomen in `docs/screenshots/phase3-*.png` | GEREED |

### Screenshots

| Situatie | UEFI | BIOS |
|---|---|---|
| Bureaublad met pictogrammen en Deskbar | [phase3-live-uefi.png](screenshots/phase3-live-uefi.png) | [phase3-live-bios.png](screenshots/phase3-live-bios.png) |
| Actief/inactief venster en Deskbar met vensterlijst | [phase3-windows-uefi.png](screenshots/phase3-windows-uefi.png) | [phase3-windows-bios.png](screenshots/phase3-windows-bios.png) |
| Geïnstalleerd systeem (UEFI-installatietest) | [phase3-installed-uefi.png](screenshots/phase3-installed-uefi.png) | — |

De opnamen komen uit `tests/test-uefi.sh` en `tests/test-bios.sh`; de
vensters worden alleen in de test-VM geopend via het SMBIOS-seriënnummer
`LINUXBEOS-THEME-DEMO`.

## Licentie

De vormgeving is vanaf nul gemaakt en valt onder de MIT-licentie in
`desktop/LICENSE`. Herkomst en het bewust vermijden van BeOS/Haiku-merken
staan in `desktop/NOTICE.md`.
