pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock screen tokens. With the system theme (~/.config/my-shell/stylix.json,
// written by Home Manager from the Stylix palette, the same file the bar
// follows) the lock uses the palette and the theme's sans font. Without it,
// the original techno HUD look: white on dark, cyan accent, Orbitron
// (bundled through FONTCONFIG_FILE in default.nix).
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
    function overlay(a) { const c = system ? pal("base05") : "#ffffff"; return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property string font: system && system.font && system.font.sans ? system.font.sans : "Orbitron"
    // Orbitron is wide and wants generous letter spacing; a normal sans needs much less
    readonly property real ls: system ? 0.35 : 1

    readonly property color fg: system ? pal("base06") : "#ffffff"
    readonly property color dim: overlay(0.6)
    readonly property color cyan: system ? pal("base0D") : "#7fdcff"   // the accent
    readonly property color line: overlay(0.35)
    readonly property color fieldLine: overlay(0.75)
    readonly property color error: system ? pal("base08") : "#ff7b63"

    // backgrounds shown behind / instead of the wallpaper
    readonly property color bg: system ? Qt.darker(pal("base00"), 1.5) : "#0b0d12"
    readonly property color gradTop: system ? Qt.lighter(pal("base00"), 1.15) : "#1d2a3a"
    readonly property color gradMid: system ? pal("base00") : "#0f141c"
    readonly property color gradBottom: system ? Qt.darker(pal("base00"), 1.6) : "#07090d"
}
