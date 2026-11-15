import QtQuick
import Quickshell
import "../widgets"
import ".."

// VPN or WireGuard connection with an on/off switch.
Column {
    id: root
    required property var vpn
    property string expandedKey: ""
    signal expandRequested(string key)
    readonly property bool open: expandedKey === vpn.uuid
    OpState { id: ops }
    readonly property bool on: vpn.state === 1 || vpn.state === 2

    function setOn(v) {
        NetService.markUserVpn(vpn.uuid)
        if (v && !on) ops.run("Connecting…", cb => NetService.op("connect", { conn: vpn.path }, cb))
        else if (!v && vpn.ac) ops.run("Disconnecting…", cb => NetService.op("deactivate", { ac: vpn.ac }, cb))
    }

    spacing: 0
    width: parent ? parent.width : 340

    ListRow {
        width: parent.width
        icon: "network-vpn-symbolic"
        title: root.vpn.id
        status: root.vpn.state === 1 ? "Connecting…" : root.vpn.state === 3 ? "Disconnecting…"
            : root.vpn.state === 2 ? "Connected" : (ops.error || ops.busy || (root.vpn.type === "wireguard" ? "WireGuard" : "VPN"))
        active: root.vpn.state === 2
        isError: ops.error !== "" && root.vpn.state !== 2
        working: root.vpn.state === 1
        open: root.open
        expandable: false
        onClicked: root.expandRequested(root.open ? "" : root.vpn.uuid)
        trailing: [ Toggle { checked: root.on; onToggled: v => root.setOn(v) } ]
    }
    Rectangle {
        visible: root.open
        width: parent.width
        height: root.open ? pcol.implicitHeight + 22 : 0
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.03)
        Column {
            id: pcol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 10 }
            spacing: 10
            InfoBlock { width: parent.width; groups: root.vpn.info || [] }
            Chip { label: "Edit…"; onClicked: Quickshell.execDetached(["nm-connection-editor", "--edit", root.vpn.uuid]) }
        }
    }
}
