pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock screen tokens. With the system theme (~/.config/my-shell/stylix.json,
// written by Home Manager from the Stylix palette, the same file the bar
// follows) the lock uses the palette and the theme's sans font. Without it,
// white on dark with a cyan accent, set in SF Pro.
Singleton {
    id: root

    property var system: null     // { polarity, colors: { base00..base0F }, font: { sans } } or null
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell/stylix.json"
        blockLoading: true
        onLoaded: { try { root.system = JSON.parse(text()) } catch (e) { root.system = null } }
        onLoadFailed: root.system = null
    }
    function pal(n) { return "#" + system.colors[n] }
    // `c` must be a real colour: a "#rrggbb" string has no .r/.g/.b, which made
    // every overlay() colour (dim, line, fieldLine) come out black.
    function overlay(a) { const c = Qt.color(system ? pal("base05") : "#ffffff"); return Qt.rgba(c.r, c.g, c.b, a) }

    // SF Pro (Home Manager installs it, homes/pride/fonts.nix) unless the system
    // theme names another sans; SF Mono for the monospace bits.
    readonly property string font: system && system.font && system.font.sans ? system.font.sans : "SFProDisplay Nerd Font"
    readonly property string mono: "Liga SFMono Nerd Font"
    // letter spacing factor for the small uppercase labels
    readonly property real ls: 0.35

    readonly property color fg: system ? pal("base06") : "#ffffff"
    readonly property color dim: overlay(0.6)
    readonly property color cyan: system ? pal("base0D") : "#7fdcff"   // the accent
    readonly property color line: overlay(0.35)
    readonly property color fieldLine: overlay(0.75)
    // surfaces for the cards on the lock panel
    readonly property color panel: Qt.rgba(bg.r, bg.g, bg.b, 0.74)
    readonly property color panelLine: overlay(0.1)
    readonly property color card: overlay(0.07)
    readonly property color cardHigh: overlay(0.13)
    readonly property color error: system ? pal("base08") : "#ff7b63"

    // backgrounds shown behind / instead of the wallpaper
    readonly property color bg: system ? Qt.darker(pal("base00"), 1.5) : "#0b0d12"
    readonly property color gradTop: system ? Qt.lighter(pal("base00"), 1.15) : "#1d2a3a"
    readonly property color gradMid: system ? pal("base00") : "#0f141c"
    readonly property color gradBottom: system ? Qt.darker(pal("base00"), 1.6) : "#07090d"

    // Motion tokens (Material 3 Expressive), same values as the shell's Theme.
    readonly property var curves: ({
        standard:    [0.2, 0, 0, 1, 1, 1],
        emphasized:  [0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1],
        fastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1],
        spatial:     [0.38, 1.21, 0.22, 1, 1, 1],
        fastEffects: [0.31, 0.94, 0.34, 1, 1, 1],
        effects:     [0.34, 0.8, 0.34, 1, 1, 1],
        slowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    })
    readonly property var durations: ({
        standard: 400, emphasized: 400, fastSpatial: 350, spatial: 500,
        fastEffects: 150, effects: 200, slowEffects: 300
    })
}
