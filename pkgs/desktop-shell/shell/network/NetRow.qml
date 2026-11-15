import QtQuick
import Quickshell
import "../widgets"
import ".."

// One Wi-Fi network (APs sharing SSID + mode + security are already merged
// by the sidecar): a row plus the details panel.
Column {
    id: root
    required property var net
    required property var dev
    property bool isActive: false
    property string expandedKey: ""
    signal expandRequested(string key)
    signal joinRequested(var net)
    readonly property bool open: expandedKey === net.key
    property bool confirmForget: false

    OpState { id: ops }
    Timer { id: forgetTimer; interval: 4000; onTriggered: root.confirmForget = false }
    readonly property bool needsForm: net.security === "wep" || net.security === "enterprise" || net.security === "enterprise-192"
    readonly property var hint: ({ wep: "WEP", enterprise: "Enterprise", "enterprise-192": "Enterprise" })

    // Router-default SSIDs: new connections get locked to the BSSID so we
    // don't wander onto some other "linksys".
    readonly property var mfrDefault: ["linksys", "linksys-a", "linksys-g", "default", "belkin54g", "NETGEAR", "o2DSL", "WLAN", "ALICE-WLAN"]

    function connect(conn) {
        if (!conn && net.connections.length > 1) { root.expandRequested(net.key); return }
        const saved = conn || net.connections[0]
        if (saved) {
            ops.run("Connecting…", cb => NetService.op("connect", { conn: saved.path, device: dev.path, ap: net.ap }, cb))
            return
        }
        if (needsForm) {
            ops.showError(hint[net.security] + " networks are set up in Network Settings")
            Quickshell.execDetached(["nm-connection-editor"])
            return
        }
        // New open / WPA / WPA3 / OWE network: NM fills in the rest and asks
        // our secret agent for the password.
        let settings = {}
        if (net.mode !== 1 && mfrDefault.includes(net.ssid)) {
            const bssid = net.bssid.split(":").map(h => parseInt(h, 16))
            settings = { "802-11-wireless": { ssid: Array.from(new TextEncoder().encode(net.ssid)), bssid: bssid } }
        }
        ops.run("Connecting…", cb => NetService.op("connect-new", { device: dev.path, ap: net.ap, settings: settings }, cb))
    }

    readonly property string status: {
        if (isActive) {
            if (dev.stateText) return dev.stateText
        } else if (ops.busy) return ops.busy
        if (ops.error) return ops.error
        if (isActive) {
            const c = NetService.net ? NetService.net.connectivity : 4
            const t = c === 2 ? "Sign-in required" : c === 3 ? "Limited connectivity" : c === 1 ? "No internet" : ""
            return t ? "Connected · " + t : "Connected"
        }
        return net.saved ? "Saved · " + net.securityLabel : net.securityLabel
    }
    function strengthIcon(s) {
        const l = s > 80 ? "excellent" : s > 55 ? "good" : s > 30 ? "ok" : s > 5 ? "weak" : "none"
        return "network-wireless-signal-" + l + "-symbolic"
    }
    function band(f) { return f >= 5925 ? "6 GHz" : f >= 4900 ? "5 GHz" : f >= 2400 ? "2.4 GHz" : f ? f + " MHz" : "—" }
    function channel(f) {
        if (f === 2484) return 14
        if (f >= 2412 && f < 2484) return (f - 2407) / 5
        if (f >= 5955) return (f - 5950) / 5
        if (f >= 5000) return (f - 5000) / 5
        return 0
    }

    spacing: 0
    width: parent ? parent.width : 340

    ListRow {
        width: parent.width
        icon: root.strengthIcon(root.net.strength)
        title: root.net.ssid
        status: root.status
        active: root.isActive
        isError: ops.error !== ""
        working: ops.busy !== "" || (root.isActive && !!root.dev.stateText)
        open: root.open
        secured: root.net.security !== "none" && root.net.security !== "owe"
        check: root.isActive
        onClicked: root.isActive ? root.expandRequested(root.open ? "" : root.net.key) : root.connect()
        onExpandClicked: root.expandRequested(root.open ? "" : root.net.key)
    }

    Rectangle {
        visible: root.open
        width: parent.width
        height: root.open ? pcol.implicitHeight + 22 : 0
        radius: 12
        color: Theme.surfaceFaint
        Rectangle { anchors.top: parent.top; width: parent.width; height: parent.radius; color: parent.color }
        Column {
            id: pcol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 10 }
            spacing: 10

            InfoBlock { width: parent.width; visible: root.isActive; groups: root.isActive ? (root.dev.activeInfo || []) : [] }
            Column {
                visible: !root.isActive
                spacing: 3
                Repeater {
                    model: [
                        ["Security", root.net.securityLabel],
                        ["Signal", root.net.strength + "% · " + root.band(root.net.frequency) + (root.channel(root.net.frequency) ? " · ch " + root.channel(root.net.frequency) : "")],
                        ["BSSID", root.net.bssid + (root.net.apCount > 1 ? " (+" + (root.net.apCount - 1) + ")" : "")],
                        ["Max rate", root.net.maxBitrate + " Mb/s"]
                    ]
                    Row {
                        required property var modelData
                        spacing: 12
                        Text { text: modelData[0]; color: Theme.muted; font.pixelSize: 12; width: 64 }
                        Text { text: modelData[1]; color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                visible: root.net.connections.length > 1
                Text { text: "Connect Using"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                Repeater {
                    model: root.net.connections
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 28; radius: 10
                        color: m.containsMouse ? Theme.hover : Theme.surfaceFaint
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.id; color: Theme.fg; font.pixelSize: 12 }
                        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: root.connect(modelData) }
                    }
                }
            }

            Row {
                spacing: 6
                Chip {
                    label: root.isActive ? "Disconnect" : "Connect"
                    onClicked: root.isActive
                        ? ops.run("Disconnecting…", cb => NetService.op("disconnect-device", { device: root.dev.path }, cb))
                        : root.connect()
                }
                Chip {
                    visible: root.net.connections.length > 0
                    label: "Edit…"
                    onClicked: Quickshell.execDetached(["nm-connection-editor", "--edit", root.net.connections[0].uuid])
                }
                Chip {
                    visible: root.net.connections.length > 0
                    label: root.confirmForget ? "Really forget?" : "Forget"
                    destructive: true
                    confirm: root.confirmForget
                    onClicked: {
                        if (!root.confirmForget) { root.confirmForget = true; forgetTimer.restart(); return }
                        root.confirmForget = false
                        ops.run("Forgetting…", cb => NetService.op("forget", { conns: root.net.connections.map(c => c.path) }, cb))
                    }
                }
            }
        }
    }
}
