pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Design tokens. Two sources:
//  - system: ~/.config/my-shell/stylix.json, written by Home Manager from the
//    Stylix palette (a base16 scheme). When present it wins, and is watched,
//    so `home-manager switch` recolours the running shell.
//  - local: libadwaita dark / light with six accents, chosen in Quick Settings
//    (theme.json). Used when there is no stylix.json.
// The lock screen keeps its own dark HUD theme.
Singleton {
    id: root

    // ---- system palette (Stylix) ---------------------------------------------------------
    property var system: null                         // { polarity, colors: { base00..base0F } } or null
    readonly property bool followsSystem: system !== null
    FileView {
        id: stylixFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell/stylix.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.system = JSON.parse(text()) } catch (e) { root.system = null } }
        onLoadFailed: root.system = null
    }
    function pal(n) { return "#" + system.colors[n] }

    // ---- local choices ---------------------------------------------------------------
    property bool darkLocal: true
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
                root.darkLocal = j.mode !== "light"
                if (j.accent && root.accents[j.accent]) root.accentName = j.accent
            } catch (e) { }
        }
    }
    Process { id: writer }
    function save() {
        writer.exec(["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "_",
            settingsPath, JSON.stringify({ mode: darkLocal ? "dark" : "light", accent: accentName })])
    }
    function setDark(on) { darkLocal = on; save() }
    function setAccent(name) { accentName = name; save() }

    // ---- surfaces ---------------------------------------------------------------------
    readonly property bool dark: system ? system.polarity !== "light" : darkLocal
    // overlay colour: the palette's text colour with the system theme, else white / black
    readonly property color overlayBase: system ? pal("base05") : (dark ? "#ffffff" : "#000000")
    // light mode uses black-based overlays where dark mode uses white-based ones
    function ov(a) { const c = overlayBase; return Qt.rgba(c.r, c.g, c.b, system || dark ? a : a * 0.85) }

    readonly property color barBg: system ? pal("base00") : (dark ? "#242424" : "#f6f5f4")
    readonly property color popoverBg: system ? pal("base01") : (dark ? "#2d2d2d" : "#ffffff")
    readonly property color osdBg: system ? Qt.rgba(popoverBg.r, popoverBg.g, popoverBg.b, 0.95)
        : (dark ? Qt.rgba(0.14, 0.14, 0.14, 0.94) : Qt.rgba(1, 1, 1, 0.95))
    readonly property color fg: system ? pal("base06") : (dark ? "#ffffff" : "#1e1e1e")
    readonly property color muted: ov(0.6)
    readonly property color faint: ov(0.38)
    readonly property color accent: system ? pal("base0D") : accents[accentName]
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
    readonly property color textBar: ov(0.9)

    readonly property color danger: system ? pal("base08") : (dark ? "#ff7b63" : "#c01c28")   // errors
    readonly property color dangerBg: system ? Qt.darker(pal("base08"), 1.3) : "#e01b24"       // destructive confirm
    readonly property color dangerSoft: system ? Qt.rgba(danger.r, danger.g, danger.b, 0.18) : Qt.rgba(0.88, 0.11, 0.14, 0.18)
    readonly property color warn: system ? pal("base0A") : (dark ? "#f5a524" : "#c64600")     // over-amplified volume
    readonly property color success: system ? pal("base0B") : "#57c26b"

    readonly property int fontSize: 13
    readonly property int radius: 8
    readonly property int iconSize: 16
    readonly property int animFast: 140

    // Motion tokens, ported from caelestia-dots/shell (Material 3 Expressive).
    // Curves are cubic-bezier spline control points: c1x,c1y,c2x,c2y,x,y per segment.
    // "Spatial" curves overshoot (y > 1): use them for position/size/scale.
    // "Effects" curves do not: use them for opacity and colour.
    readonly property var curves: ({
        standard:      [0.2, 0, 0, 1, 1, 1],
        emphasized:    [0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1],
        fastSpatial:   [0.42, 1.67, 0.21, 0.9, 1, 1],
        spatial:       [0.38, 1.21, 0.22, 1, 1, 1],
        slowSpatial:   [0.39, 1.29, 0.35, 0.98, 1, 1],
        fastEffects:   [0.31, 0.94, 0.34, 1, 1, 1],
        effects:       [0.34, 0.8, 0.34, 1, 1, 1],
        slowEffects:   [0.34, 0.88, 0.34, 1, 1, 1]
    })
    readonly property real animScale: Config.animScale
    readonly property var durations: ({
        standard: 400, emphasized: 400,
        fastSpatial: 350, spatial: 500, slowSpatial: 650,
        fastEffects: 150, effects: 200, slowEffects: 300
    })
}
