pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".."

// PipeWire state for the volume panel: devices, application streams,
// helpers and the persisted "allow volume above 100%" option.
Singleton {
    id: root

    // ---- nodes -------------------------------------------------------------
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    function cls(n) { return (n && n.properties && n.properties["media.class"]) || "" }
    readonly property var sinks: nodes.filter(n => cls(n) === "Audio/Sink")
    readonly property var sources: nodes.filter(n => cls(n) === "Audio/Source")
    // Our own level meters (PwNodePeakMonitor) show up as capture streams.
    function isOurs(n) { return ((n.properties && n.properties["application.name"]) || "") === "Quickshell Peak Detect" }
    readonly property var playStreams: nodes.filter(n => cls(n) === "Stream/Output/Audio" && !isOurs(n))
    readonly property var recStreams: nodes.filter(n => cls(n) === "Stream/Input/Audio" && !isOurs(n))
    // Nodes must be tracked before their `audio` is readable.
    PwObjectTracker { objects: root.nodes }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // ---- helpers -------------------------------------------------------------
    function vol(n) { return n && n.audio ? n.audio.volume : 0 }
    function muted(n) { return n && n.audio ? n.audio.muted : false }
    function setVolume(n, v) {
        if (!n || !n.audio) return
        n.audio.volume = Math.max(0, Math.min(maxVolume, v))
        if (v > 0) n.audio.muted = false
    }
    function toggleMute(n) { if (n && n.audio) n.audio.muted = !n.audio.muted }
    function nudge(n, delta) { setVolume(n, vol(n) + delta) }
    function deviceName(n) { return n ? (n.nickname || n.description || n.name) : "" }
    function appName(n) {
        const p = n.properties || {}
        return p["application.name"] || p["node.nick"] || n.description || n.name
    }
    // media title shown under the app name (e.g. the tab or track)
    function appDetail(n) {
        const p = n.properties || {}
        const m = p["media.name"] || ""
        return m && m !== appName(n) ? m : ""
    }
    function appIcon(n) {
        const p = n.properties || {}
        const guess = (p["application.icon-name"] || p["application.process.binary"] || appName(n) || "").toLowerCase()
        return Quickshell.iconPath(guess, true) || Quickshell.iconPath("audio-x-generic", true)
    }
    function volumeIcon(v, mutedNow) {
        if (mutedNow || v === 0) return "audio-volume-muted-symbolic"
        return v < 0.34 ? "audio-volume-low-symbolic" : v < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"
    }
    function setDefaultSink(n) { Pipewire.preferredDefaultAudioSink = n }
    function setDefaultSource(n) { Pipewire.preferredDefaultAudioSource = n }

    // ---- microphone in use ---------------------------------------------------------
    // A capture stream with a live link: apps often keep idle streams open,
    // which have no link.
    readonly property bool micInUse: {
        const links = Pipewire.links ? Pipewire.links.values : []
        return recStreams.some(s => links.some(l => l.source === s || l.target === s))
    }

    // ---- persisted option: allow volume above 100% -----------------------------------
    property bool allowBoost: false
    readonly property real maxVolume: allowBoost ? 1.5 : 1.0
    readonly property string settingsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell/audio.json"
    FileView {
        path: root.settingsPath
        blockLoading: true
        onLoaded: { try { root.allowBoost = !!JSON.parse(text()).allowBoost } catch (e) { } }
    }
    Process { id: writer }
    function setAllowBoost(on) {
        allowBoost = on
        // coming back to a 100% cap: pull an over-amplified output down
        if (!on && sink && vol(sink) > 1) setVolume(sink, 1)
        writer.exec({ command: ["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "_",
            settingsPath, JSON.stringify({ allowBoost: on })] })
    }
}
