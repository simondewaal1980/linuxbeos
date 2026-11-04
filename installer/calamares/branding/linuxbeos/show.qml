/* === LinuxBeOS Calamares-slideshow (fase 1) ===
 *
 * Bewust zonder externe afbeeldingen: de slideshow gebruikt alleen tekst
 * en kleuren, zodat er geen licentie- of merkenrisico's ontstaan.
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
        interval: 5000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        centeredText: qsTr("LinuxBeOS installeren…\n\nDe live-omgeving wordt naar de schijf gekopieerd.")
    }

    Slide {
        centeredText: qsTr("Een open-source desktop\nin de geest van BeOS 5.")
    }

    Slide {
        centeredText: qsTr("Fase 1: een betrouwbare installatie op ext4.\n\nBtrfs, snapshots en het BeOS-thema volgen in fase 2 en 3.")
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}
