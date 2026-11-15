import QtQuick
import Quickshell
import "../widgets"
import ".."

// Wired / mobile broadband / Bluetooth PAN+DUN device.
Column {
    id: root
    required property var dev
    property string expandedKey: ""
    signal expandRequested(string key)
    readonly property bool open: expandedKey === dev.path
    OpState { id: ops }

    function connect(conn) {
        ops.run("Connecting…", cb => NetService.op("connect", { conn: conn ? conn.path : null, device: dev.path }, cb))
    }

    spacing: 0
    width: parent ? parent.width : 340

    ListRow {
        width: parent.width
        icon: root.dev.icon
        title: root.dev.name
        status: root.dev.working ? root.dev.status : (ops.busy || ops.error || root.dev.status)
        active: root.dev.activated
        isError: ops.error !== ""
        working: root.dev.working
        open: root.open
        enabled: root.dev.usable
        onClicked: root.dev.activated ? root.expandRequested(root.open ? "" : root.dev.path) : root.connect(null)
        onExpandClicked: root.expandRequested(root.open ? "" : root.dev.path)
    }
    Rectangle {
        visible: root.open
        width: parent.width
        height: root.open ? pcol.implicitHeight + 22 : 0
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.03)
        Rectangle { anchors.top: parent.top; width: parent.width; height: parent.radius; color: parent.color }
        Column {
            id: pcol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 10 }
            spacing: 10
            InfoBlock { width: parent.width; visible: root.dev.activated; groups: root.dev.activated ? (root.dev.info || []) : [] }
            Column {
                width: parent.width
                spacing: 4
                visible: root.dev.available.length > 0
                Text { text: "Connections"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                Repeater {
                    model: root.dev.available
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 28; radius: 10
                        color: m.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.04)
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.id; color: Theme.fg; font.pixelSize: 12 }
                        Text { visible: modelData.active; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "✓"; color: Theme.accent; font.pixelSize: 12 }
                        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: root.connect(modelData) }
                    }
                }
            }
            Row {
                spacing: 6
                Chip { visible: root.dev.activated; label: "Disconnect"; onClicked: ops.run("Disconnecting…", cb => NetService.op("disconnect-device", { device: root.dev.path }, cb)) }
                Chip { visible: !root.dev.activated && root.dev.usable; label: "Connect"; onClicked: root.connect(null) }
                Chip { visible: root.dev.activeAc !== null; label: "Edit…"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
            }
        }
    }
}
