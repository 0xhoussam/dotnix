import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../widgets"
import ".."

// PipeWire side of a Bluetooth audio device: the card (profiles: A2DP
// codecs, HFP/HSP, off) and its sink/source, matched by BT address. Uses
// pactl (pipewire-pulse) since Quickshell.Services.Pipewire has no card API.
Column {
    id: root
    required property string address
    spacing: 4
    property var card: null
    property var sink: null
    property var source: null
    property string defSink: ""
    property string defSource: ""
    visible: card !== null

    function matches(o) {
        const p = o.properties || {}
        const a = root.address.toUpperCase()
        return (p["api.bluez5.address"] || p["device.string"] || "").toUpperCase() === a
    }
    function refresh() { load.running = true }
    Component.onCompleted: refresh()

    Process {
        id: load
        command: ["bash", "-c",
            'printf \'{"cards":%s,"sinks":%s,"sources":%s,"ds":"%s","dsrc":"%s"}\' ' +
            '"$(pactl -f json list cards)" "$(pactl -f json list sinks)" "$(pactl -f json list sources)" ' +
            '"$(pactl get-default-sink)" "$(pactl get-default-source)"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    root.card = j.cards.find(root.matches) || null
                    root.sink = j.sinks.find(root.matches) || null
                    root.source = j.sources.find(s => root.matches(s) && !/\.monitor$/.test(s.name)) || null
                    root.defSink = j.ds
                    root.defSource = j.dsrc
                } catch (e) { root.card = null }
            }
        }
    }
    Process { id: act; onExited: root.refresh() }
    function run(args) { act.exec(args) }

    function pretty(name, desc) {
        if (name === "off") return "Off"
        const d = desc || name
        const codec = (/codec ([\w-]+)/i.exec(d) || [])[1]
        if (/a2dp/i.test(d) || /a2dp/i.test(name)) return codec ? "Music (A2DP) · " + codec : "Music (A2DP)"
        if (/hsp|hfp|head/i.test(d) || /headset|handsfree/i.test(name)) return codec ? "Calls (HFP) · " + codec : "Calls (HFP, with mic)"
        if (/bap|le audio/i.test(d) || /bap/i.test(name)) return codec ? "LE Audio · " + codec : "LE Audio"
        return d
    }
    // Usable profiles, best first (priority), "off" last.
    readonly property var profiles: {
        if (!card) return []
        return Object.keys(card.profiles || {})
            .map(n => ({ name: n, p: card.profiles[n] }))
            .filter(x => x.p.available !== false)
            .sort((a, b) => (a.name === "off") - (b.name === "off") || (b.p.priority || 0) - (a.p.priority || 0))
            .map(x => ({ name: x.name, label: pretty(x.name, x.p.description) }))
    }

    Text { text: "Audio Profile"; color: Theme.muted; font { pixelSize: 12; bold: true } topPadding: 4 }
    Repeater {
        model: root.profiles
        Rectangle {
            required property var modelData
            readonly property bool active: root.card && root.card.active_profile === modelData.name
            width: root.width
            height: 28
            radius: 10
            color: active ? Qt.rgba(0.21, 0.52, 0.89, 0.22) : ma.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.04)
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: Theme.fg; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width - 40 }
            Text { visible: parent.active; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "✓"; color: Theme.accent; font.pixelSize: 12 }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: root.run(["pactl", "set-card-profile", root.card.name, modelData.name]) }
        }
    }
    Row {
        spacing: 6
        visible: root.sink !== null || root.source !== null
        Chip {
            visible: root.sink !== null
            readonly property bool isDef: root.sink && root.sink.name === root.defSink
            label: isDef ? "Default Output" : "Use as Output"
            active: isDef
            onClicked: if (!isDef) root.run(["pactl", "set-default-sink", root.sink.name])
        }
        Chip {
            visible: root.source !== null
            readonly property bool isDef: root.source && root.source.name === root.defSource
            label: isDef ? "Default Mic" : "Use as Mic"
            active: isDef
            onClicked: if (!isDef) root.run(["pactl", "set-default-source", root.source.name])
        }
    }
}
