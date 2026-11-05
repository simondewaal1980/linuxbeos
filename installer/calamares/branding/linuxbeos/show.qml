/* === LinuxBeOS Calamares-slideshow (fase 4) ===
 *
 * De slideshow gebruikt alleen tekst en kleuren: geen externe afbeeldingen
 * en geen BeOS/Haiku-bestanden. De slides lichten de pijlers van de
 * distributie toe: open source, Debian Sid, Btrfs-snapshots en de
 * BeOS 5-look.
 */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation
{
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 6500
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        centeredText: qsTr("Welkom bij LinuxBeOS\n\nEen open-source desktop in de geest van BeOS 5.")
    }

    Slide {
        centeredText: qsTr("Vier pijlers\n\n• Open source, volledig vanaf nul opgebouwd\n• Debian Sid als stabiele pakketbasis\n• Btrfs met snapshots en rollback\n• Een herkenbare BeOS 5-desktop op XFCE")
    }

    Slide {
        centeredText: qsTr("Debian Sid als basis\n\nDuizenden vrije pakketten, systemd en de nieuwste XFCE.\nZo blijft het systeem actueel zonder de BeOS-look op te geven.")
    }

    Slide {
        centeredText: qsTr("Btrfs + Snapper\n\nSubvolumes voor systeem, home en snapshots.\nEen rollback zet / terug zonder je persoonlijke bestanden te verliezen.")
    }

    Slide {
        centeredText: qsTr("BeOS 5-look\n\nGele titeltab, grijze vlakke widgets, een compacte Deskbar,\neigen pictogrammen en een donker terminalprofiel.")
    }

    Slide {
        centeredText: qsTr("Klaar voor installatie\n\nDe live-omgeving wordt naar de schijf gekopieerd.\nNa de herstart vind je dezelfde look terug op je nieuwe systeem.")
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}
