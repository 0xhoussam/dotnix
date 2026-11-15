pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Design tokens (libadwaita palette) with a dark and a light mode and a
// choice of accent colours, persisted in ~/.config/my-shell/theme.json.
// The lock screen keeps its own dark HUD theme.
Singleton {
    id: root

    // ---- choices ---------------------------------------------------------------
    property bool dark: true
    property string accentName: "blue"
    readonly property var accents: ({
        blue: "#3584e4", purple: "#9141ac", green: "#26a269", orange: "#e66100", pink: "#d56199", teal: "#2190a4"
    })
    readonly property string settingsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell/theme.json"
    FileView {
        path: root.settingsPath
        blockLoading: true
        onLoaded: {
            try {
                const j = JSON.parse(text())
                root.dark = j.mode !== "light"
                if (j.accent && root.accents[j.accent]) root.accentName = j.accent
            } catch (e) { }
        }
    }
    Process { id: writer }
    function save() {
        writer.exec(["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "_",
            settingsPath, JSON.stringify({ mode: dark ? "dark" : "light", accent: accentName })])
    }
    function setDark(on) { dark = on; save() }
    function setAccent(name) { accentName = name; save() }

    // ---- surfaces ---------------------------------------------------------------------
    // light mode uses black-based overlays where dark mode uses white-based ones
    function ov(a) { return dark ? Qt.rgba(1, 1, 1, a) : Qt.rgba(0, 0, 0, a * 0.85) }

    readonly property color barBg: dark ? "#242424" : "#f6f5f4"
    readonly property color popoverBg: dark ? "#2d2d2d" : "#ffffff"
    readonly property color osdBg: dark ? Qt.rgba(0.14, 0.14, 0.14, 0.94) : Qt.rgba(1, 1, 1, 0.95)
    readonly property color fg: dark ? "#ffffff" : "#1e1e1e"
    readonly property color muted: ov(0.6)
    readonly property color faint: ov(0.38)
    readonly property color accent: accents[accentName]
    readonly property color accentFg: "#ffffff"
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.22 : 0.18)
    readonly property color accentBar: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
    readonly property color card: ov(0.08)
    readonly property color hover: ov(0.1)

    readonly property color surface: ov(0.05)        // rows, cards
    readonly property color surfaceFaint: ov(0.035)  // nested panels
    readonly property color surfaceHover: ov(0.12)
    readonly property color field: ov(0.08)          // inputs, chips, separators
    readonly property color track: ov(0.14)          // slider / progress tracks
    readonly property color trackFill: ov(0.22)      // level meter inside a track
    readonly property color tick: ov(0.5)
    readonly property color toggleOff: ov(0.18)
    readonly property color stackLayer: ov(0.07)     // cards stacked behind a notification
    readonly property color border: ov(0.07)
    readonly property color textSoft: ov(0.85)
    readonly property color textDim: ov(0.75)
    readonly property color textBar: dark ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(0, 0, 0, 0.85)

    readonly property color danger: dark ? "#ff7b63" : "#c01c28"   // errors
    readonly property color dangerBg: "#e01b24"                    // destructive confirm
    readonly property color dangerSoft: Qt.rgba(0.88, 0.11, 0.14, 0.18)
    readonly property color warn: dark ? "#f5a524" : "#c64600"     // over-amplified volume

    readonly property int fontSize: 13
    readonly property int radius: 8
    readonly property int iconSize: 16
    readonly property int animFast: 140
}
