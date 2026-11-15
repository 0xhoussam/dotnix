import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../audio"
import "../widgets"
import ".."

// PipeWire side of a Bluetooth audio device: the card (profiles: A2DP
// codecs, HFP/HSP, off) and its sink/source, matched by BT address. Cards
// come from `pw-dump`, profiles are switched with `wpctl set-profile`, and
// default devices through Quickshell's Pipewire service (pactl is not
// installed on this system).
Column {
    id: root
    required property string address
    spacing: 4
    property var card: null      // { id, active, profiles: [{index,name,description,priority}] }
    visible: card !== null

    function addr(n) { return ((n.properties && n.properties["api.bluez5.address"]) || "").toUpperCase() }
    readonly property var sink: AudioService.sinks.find(n => addr(n) === address.toUpperCase()) || null
    readonly property var source: AudioService.sources.find(n => addr(n) === address.toUpperCase()) || null

    function refresh() { dump.running = true }
    Component.onCompleted: refresh()

    Process {
        id: dump
        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const objs = JSON.parse(text)
                    const a = root.address.toUpperCase()
                    const dev = objs.find(o => o.type === "PipeWire:Interface:Device" && o.info && o.info.props
                        && (o.info.props["api.bluez5.address"] || o.info.props["device.string"] || "").toUpperCase() === a)
                    if (!dev) { root.card = null; return }
                    const params = dev.info.params || {}
                    const active = (params.Profile && params.Profile[0]) ? params.Profile[0].index : -1
                    root.card = {
                        id: dev.id,
                        active: active,
                        profiles: (params.EnumProfile || []).filter(p => p.available !== "no")
                    }
                } catch (e) { root.card = null }
            }
        }
    }
    Process { id: act; onExited: root.refresh() }
    function setProfile(index) { act.exec(["wpctl", "set-profile", String(root.card.id), String(index)]) }

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
        return card.profiles.slice()
            .sort((a, b) => (a.name === "off") - (b.name === "off") || (b.priority || 0) - (a.priority || 0))
            .map(p => ({ index: p.index, label: pretty(p.name, p.description) }))
    }

    Text { text: "Audio Profile"; color: Theme.muted; font { pixelSize: 12; bold: true } topPadding: 4 }
    Repeater {
        model: root.profiles
        Rectangle {
            required property var modelData
            readonly property bool active: root.card && root.card.active === modelData.index
            width: root.width
            height: 28
            radius: 10
            color: active ? Qt.rgba(0.21, 0.52, 0.89, 0.22) : ma.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.04)
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: Theme.fg; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width - 40 }
            Text { visible: parent.active; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "✓"; color: Theme.accent; font.pixelSize: 12 }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: root.setProfile(modelData.index) }
        }
    }
    Row {
        spacing: 6
        visible: root.sink !== null || root.source !== null
        Chip {
            visible: root.sink !== null
            readonly property bool isDef: root.sink !== null && root.sink === AudioService.sink
            label: isDef ? "Default Output" : "Use as Output"
            active: isDef
            onClicked: if (!isDef) AudioService.setDefaultSink(root.sink)
        }
        Chip {
            visible: root.source !== null
            readonly property bool isDef: root.source !== null && root.source === AudioService.source
            label: isDef ? "Default Mic" : "Use as Mic"
            active: isDef
            onClicked: if (!isDef) AudioService.setDefaultSource(root.source)
        }
    }
}
