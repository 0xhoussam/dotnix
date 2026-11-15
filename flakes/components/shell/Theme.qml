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

    // surfaces and lines drawn over the dark popovers
    readonly property color surface: Qt.rgba(1, 1, 1, 0.05)       // rows, cards
    readonly property color surfaceFaint: Qt.rgba(1, 1, 1, 0.035) // nested panels
    readonly property color surfaceHover: Qt.rgba(1, 1, 1, 0.12)
    readonly property color field: Qt.rgba(1, 1, 1, 0.08)         // inputs, chips, separators
    readonly property color track: Qt.rgba(1, 1, 1, 0.14)         // slider / progress tracks
    readonly property color border: Qt.rgba(1, 1, 1, 0.07)
    readonly property color accentSoft: Qt.rgba(0.21, 0.52, 0.89, 0.22) // active row
    readonly property color textSoft: Qt.rgba(1, 1, 1, 0.85)
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.75)
    readonly property color textBar: Qt.rgba(1, 1, 1, 0.88)
    readonly property color danger: "#ff7b63"   // errors
    readonly property color dangerBg: "#e01b24" // destructive confirm
    readonly property color warn: "#f5a524"     // over-amplified volume

    readonly property int fontSize: 13
    readonly property int radius: 8
    readonly property int iconSize: 16
    readonly property int animFast: 140
}
