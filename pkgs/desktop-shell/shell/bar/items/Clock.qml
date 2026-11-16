import QtQuick
import Quickshell
import "../.."
import "../../motion"

// Center clock: "Jun 04  12:16". Click toggles the date/notification panel.
Pill {
    active: UiState.panelOpen
    onClicked: UiState.togglePanel()
    SystemClock { id: clock; precision: SystemClock.Minutes }
    AnimText {
        text: Qt.formatDateTime(clock.date, "MMM dd  HH:mm")
        color: Theme.fg
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
}
