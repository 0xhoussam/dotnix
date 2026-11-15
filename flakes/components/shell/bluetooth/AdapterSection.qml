import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../widgets"
import ".."

// Adapter controls under the header: adapter picker (multi-adapter setups),
// visible name, and a discoverable toggle with countdown.
Column {
    id: root
    spacing: 6
    property string picked: "" // adapterId
    readonly property var adapters: Bluetooth.adapters ? Bluetooth.adapters.values : []
    readonly property var adapter: adapters.find(a => a.adapterId === picked) || Bluetooth.defaultAdapter || adapters[0] || null

    Row {
        visible: root.adapters.length > 1
        spacing: 6
        Repeater {
            model: root.adapters
            Chip {
                required property var modelData
                label: modelData.name || modelData.adapterId
                active: modelData === root.adapter
                onClicked: root.picked = modelData.adapterId
            }
        }
    }

    Rectangle {
        visible: root.adapter !== null
        width: parent.width
        height: 52
        radius: 12
        color: Theme.surface

        // local countdown; BlueZ flips Discoverable back off when it expires
        property int remaining: 0
        readonly property bool disc: root.adapter ? root.adapter.discoverable : false
        onDiscChanged: sync()
        function sync() {
            remaining = disc && root.adapter.discoverableTimeout > 0 ? root.adapter.discoverableTimeout : 0
        }
        Timer { interval: 1000; repeat: true; running: parent.remaining > 0; onTriggered: parent.remaining = Math.max(0, parent.remaining - 1) }

        Column {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Text { text: "Discoverable"; color: Theme.fg; font.pixelSize: Theme.fontSize }
            Text {
                color: Theme.muted; font.pixelSize: 11
                text: {
                    if (!root.adapter) return ""
                    if (!parent.parent.disc) return "Visible to others as “" + root.adapter.name + "”"
                    const r = parent.parent.remaining
                    if (root.adapter.discoverableTimeout === 0 || r === 0) return "Visible to nearby devices"
                    return "Visible for " + Math.floor(r / 60) + ":" + String(r % 60).padStart(2, "0")
                }
            }
        }
        Toggle {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            checked: parent.disc
            onToggled: v => {
                // incoming pairing needs Pairable too (often off by default)
                if (v) root.adapter.pairable = true
                root.adapter.discoverable = v
            }
        }
    }
}
