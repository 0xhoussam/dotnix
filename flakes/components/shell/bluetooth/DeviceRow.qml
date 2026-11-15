import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../widgets"
import ".."

// One device: a clickable row (pair / connect / disconnect) plus an
// expandable panel mirroring blueman's device menu and info dialog.
Column {
    id: root
    required property var device
    property string expandedAddress: ""
    signal expandRequested(string address)
    readonly property bool open: expandedAddress === device.address

    property string busy: ""
    property string error: ""
    property bool confirmForget: false
    property var info: ({})

    Timer { id: errTimer; interval: 8000; onTriggered: root.error = "" }
    Timer { id: forgetTimer; interval: 4000; onTriggered: root.confirmForget = false }
    function showError(e) {
        if (BtService.isCancelled(e)) return
        error = BtService.errorText(e)
        errTimer.restart()
    }
    function run(label, fn) {
        if (busy) return
        error = ""
        busy = label
        fn((ok, v) => { busy = ""; if (!ok) showError(v) })
    }
    function primary() {
        if (device.blocked) return showError("Device is blocked — unblock it in the details panel")
        if (device.connected) return run("Disconnecting…", cb => BtService.disconnect(device, cb))
        if (device.paired) return run("Connecting…", cb => BtService.connect(device, cb))
        run("Pairing…", cb => BtService.pairTrustConnect(device, cb))
    }
    readonly property bool connecting: device.state === BluetoothDeviceState.Connecting
    readonly property string status: {
        if (busy) return busy
        if (error) return error
        if (connecting) return "Connecting…"
        if (device.blocked) return "Blocked"
        if (device.connected) {
            const pct = device.batteryAvailable ? Math.round(device.battery * 100) : -1
            return pct >= 0 ? "Connected · " + pct + "%" : "Connected"
        }
        return device.paired ? "Not connected" : "Not paired"
    }

    onOpenChanged: if (open) BtService.getAll(device, v => info = v)
    Timer { interval: 2000; repeat: true; running: root.open; onTriggered: BtService.getAll(root.device, v => root.info = v) }

    spacing: 0
    width: parent ? parent.width : 340

    Rectangle {
        width: parent.width
        height: 50
        radius: 12
        color: root.device.connected ? Qt.rgba(0.21, 0.52, 0.89, 0.22) : main.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
        Behavior on color { ColorAnimation { duration: 140 } }
        // square off the bottom corners while the details panel is open
        Rectangle { visible: root.open; anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: parent.color }

        MouseArea { id: main; anchors { fill: parent; rightMargin: 40 } hoverEnabled: true; onClicked: root.primary() }
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 10
            Image { layer.enabled: true; layer.effect: Tint {}
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; sourceSize: Qt.size(36, 36)
                source: Quickshell.iconPath((root.device.icon ? root.device.icon + "-symbolic" : "bluetooth-symbolic"), true)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: BtService.displayName(root.device); color: Theme.fg; font { pixelSize: Theme.fontSize; bold: true } elide: Text.ElideRight; width: 230 }
                Text { text: root.status; color: root.error ? "#ff7b63" : (root.device.connected ? Qt.rgba(1, 1, 1, 0.75) : Theme.muted); font.pixelSize: 11; elide: Text.ElideRight; width: 230 }
            }
        }
        Text {
            visible: root.busy !== "" || root.connecting
            anchors { right: parent.right; rightMargin: 44; verticalCenter: parent.verticalCenter }
            text: "⟳"; color: Theme.muted; font.pixelSize: 16
            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.visible }
        }
        Rectangle {
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            width: 28; height: 28; radius: 14
            color: chev.containsMouse ? Theme.hover : "transparent"
            Text { anchors.centerIn: parent; text: root.open ? "▴" : "▾"; color: Theme.muted; font.pixelSize: 12 }
            MouseArea { id: chev; anchors.fill: parent; hoverEnabled: true; onClicked: root.expandRequested(root.open ? "" : root.device.address) }
        }
    }

    // ---- details panel
    Rectangle {
        id: panel
        visible: root.open
        width: parent.width
        height: root.open ? pcol.implicitHeight + 22 : 0
        color: Qt.rgba(1, 1, 1, 0.03)
        radius: 12
        Rectangle { anchors.top: parent.top; width: parent.width; height: parent.radius; color: parent.color }

        Column {
            id: pcol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 10 }
            spacing: 10

            Column {
                spacing: 3
                component InfoRow: Row {
                    property string k
                    property string v
                    spacing: 12
                    Text { text: k; color: Theme.muted; font.pixelSize: 12; width: 64 }
                    Text { text: v; color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
                }
                function rssiText(r) {
                    if (!r) return "—"
                    const q = r >= -55 ? "excellent" : r >= -67 ? "good" : r >= -80 ? "fair" : "weak"
                    return r + " dBm (" + q + ")"
                }
                InfoRow { k: "Address"; v: root.device.address }
                InfoRow { k: "Type"; v: root.info.Icon || root.device.icon || "—" }
                InfoRow { k: "Signal"; v: parent.rssiText(root.info.RSSI) }
                InfoRow { k: "Battery"; v: root.device.batteryAvailable ? Math.round(root.device.battery * 100) + "%" : "—" }
            }

            // rename
            Rectangle {
                width: parent.width; height: 32; radius: 16
                color: Qt.rgba(1, 1, 1, 0.08)
                TextInput {
                    id: rename
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg; font.pixelSize: Theme.fontSize
                    text: BtService.displayName(root.device)
                    // Enter saves; empty resets to the device's own name
                    onAccepted: { BtService.setAlias(root.device, text.trim()); focus = false }
                    Text { visible: !rename.text; text: "Rename device"; color: Theme.faint; font: rename.font }
                }
            }

            Column {
                width: parent.width
                spacing: 4
                component ToggleRow: Rectangle {
                    property string label
                    property string hint
                    property bool checked
                    signal toggled(bool v)
                    width: parent.width; height: 44; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.04)
                    Column {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        Text { text: label; color: Theme.fg; font.pixelSize: Theme.fontSize }
                        Text { text: hint; color: Theme.muted; font.pixelSize: 11 }
                    }
                    Toggle { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } checked: parent.checked; onToggled: v => parent.toggled(v) }
                }
                ToggleRow { label: "Trusted"; hint: "Connect without asking"; checked: root.device.trusted; onToggled: v => root.device.trusted = v }
                ToggleRow {
                    visible: root.device.paired
                    height: visible ? 44 : 0
                    label: "Auto-connect"; hint: "Reconnect when Bluetooth turns on"
                    checked: BtService.settings.autoConnect.includes(root.device.address)
                    onToggled: v => BtService.toggleAutoConnect(root.device.address, v)
                }
                ToggleRow { label: "Blocked"; hint: "Refuse all connections"; checked: root.device.blocked; onToggled: v => root.device.blocked = v }
            }

            // per-profile connect
            readonly property var uuids: root.info.UUIDs || []
            readonly property var profiles: uuids.filter(u => BtUtil.connectable.includes(BtUtil.uuid16(u)))
            Column {
                width: parent.width
                spacing: 4
                visible: root.device.paired && parent.profiles.length > 0
                Text { text: "Services"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                Repeater {
                    model: pcol.profiles
                    Row {
                        required property string modelData
                        width: parent.width
                        Text { width: parent.width - 64; anchors.verticalCenter: parent.verticalCenter; leftPadding: 12; text: BtUtil.serviceName(modelData); color: Theme.fg; font.pixelSize: 12 }
                        Chip { label: "▶"; padX: 8; onClicked: root.run("Connecting…", cb => BtService.connectProfile(root.device, modelData, cb)) }
                        Chip { label: "■"; padX: 8; onClicked: root.run("Disconnecting…", cb => BtService.disconnectProfile(root.device, modelData, cb)) }
                    }
                }
            }

            Loader {
                width: parent.width
                active: root.open && root.device.connected && BtUtil.isAudio(root.device, pcol.uuids)
                sourceComponent: BtAudio { width: panel.width - 24; address: root.device.address }
            }

            // actions
            Row {
                width: parent.width
                spacing: 6
                Chip { visible: root.busy === "Pairing…"; label: "Cancel"; onClicked: BtService.cancelPairing(root.device) }
                Chip {
                    visible: root.device.connected && pcol.uuids.some(u => BtUtil.uuid16(u) === 0x1105)
                    label: "Send Files…"
                    onClicked: Agents.send({ type: "pick-send", address: root.device.address, title: "Send files to " + BtService.displayName(root.device) })
                }
                Chip {
                    visible: root.device.paired
                    label: root.confirmForget ? "Really forget?" : "Forget"
                    destructive: true
                    confirm: root.confirmForget
                    onClicked: {
                        if (!root.confirmForget) { root.confirmForget = true; forgetTimer.restart(); return }
                        root.confirmForget = false
                        root.run("Removing…", cb => BtService.remove(root.device, cb))
                    }
                }
            }
        }
    }
}
