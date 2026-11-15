pragma Singleton
import QtQuick
import Quickshell

// HUD tokens from lock/style.scss. Orbitron comes from FONTCONFIG_FILE.
Singleton {
    readonly property string font: "Orbitron"
    readonly property color fg: "#ffffff"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.6)
    readonly property color cyan: "#7fdcff"
    readonly property color line: Qt.rgba(1, 1, 1, 0.35)
    readonly property color error: "#ff7b63"
}
