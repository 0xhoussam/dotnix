import QtQuick
import Quickshell.Hyprland
import "../.."

// Active Hyprland keyboard layout. Hyprland has no current-layout getter;
// it only emits `activelayout` on change, so seed with a placeholder.
Pill {
    // "English (US)" -> "En", "French" -> "Fr"
    function short(layout) {
        const w = layout.trim()
        return (w.charAt(0) || "").toUpperCase() + (w.charAt(1) || "").toLowerCase()
    }
    property string layout: "En"

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            // data = "<keyboard name>,<layout name>"
            const i = event.data.indexOf(",")
            layout = short(event.data.slice(i + 1))
        }
    }
    Text {
        text: layout
        color: Qt.rgba(1, 1, 1, 0.88)
        font.pixelSize: Theme.fontSize
        font.bold: true
    }
}
