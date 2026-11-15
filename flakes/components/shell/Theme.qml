pragma Singleton
import QtQuick
import Quickshell

// Design tokens, ported from bar/style.scss (libadwaita dark palette).
Singleton {
    readonly property color barBg: "#242424"
    readonly property color fg: "#ffffff"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.6)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.38)
    readonly property color accent: "#3584e4"
    readonly property color accentFg: "#ffffff"
    readonly property color card: Qt.rgba(1, 1, 1, 0.08)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.1)
    readonly property color popoverBg: "#2d2d2d"

    readonly property int fontSize: 13
    readonly property int radius: 8
    readonly property int iconSize: 16
    readonly property int animFast: 140
}
