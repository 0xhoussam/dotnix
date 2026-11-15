import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Bluetooth
import "../bar/items"
import "../widgets"
import ".."

// Bluetooth indicator + popup: power, discoverable, devices (connected / my
// devices / nearby) with per-device panels, file transfers, options.
Pill {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property var all: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property bool anyConnected: all.some(d => d.connected)
    property string expanded: ""
    property string powerError: ""

    active: pop.open
    onClicked: pop.open = !pop.open

    function byName(a, b) { return BtService.displayName(a).localeCompare(BtService.displayName(b)) }
    // Re-evaluates when a device's connected / paired / name changes.
    readonly property var connectedList: all.filter(d => d.connected).sort(byName)
    readonly property var pairedList: all.filter(d => d.paired && !d.connected).sort(byName)
    readonly property var nearbyList: all
        .filter(d => !d.paired && !d.connected && (BtService.settings.showUnnamed || d.name))
        .sort(byName).slice(0, 25)

    Image { layer.enabled: true; layer.effect: Tint {}
        width: 16; height: 16; sourceSize: Qt.size(32, 32)
        source: Quickshell.iconPath(BtService.rfHard || !root.powered ? "bluetooth-disabled-symbolic"
            : root.anyConnected ? "bluetooth-active-symbolic" : "bluetooth-symbolic", true)
    }

    // scan only while the popup is open
    property bool weStarted: false
    function startScan() {
        if (!adapter || !adapter.enabled || adapter.discovering) return
        adapter.discovering = true
        weStarted = true
    }
    function stopScan() {
        if (!weStarted) return
        weStarted = false
        if (adapter) adapter.discovering = false
    }
    Connections {
        target: root.adapter
        function onEnabledChanged() { if (root.adapter.enabled && pop.open) root.startScan() }
    }
    function setPower(on) {
        powerError = ""
        if (!adapter) { powerError = "No Bluetooth adapter found"; return }
        if (on) BtService.unblock()
        adapter.enabled = on
        if (on && pop.open) startScan()
    }

    PopupCard {
        id: pop
        anchorItem: root
        cardWidth: 392
        spacing: 8
        onOpenChanged: if (open) root.startScan(); else root.stopScan()


        // header
        Item {
            width: parent.width; height: 28
            Text { text: "Bluetooth"; color: Theme.fg; font { pixelSize: 16; bold: true } anchors.verticalCenter: parent.verticalCenter }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8
                Text {
                    visible: root.adapter && root.adapter.discovering
                    text: "⟳"; color: Theme.muted; font.pixelSize: 16
                    RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.visible }
                }
                Rectangle {
                    visible: root.powered && root.adapter && !root.adapter.discovering
                    width: 26; height: 26; radius: 13
                    color: scan.containsMouse ? Theme.hover : "transparent"
                    Text { anchors.centerIn: parent; text: "↻"; color: Theme.muted; font.pixelSize: 15 }
                    MouseArea { id: scan; anchors.fill: parent; hoverEnabled: true; onClicked: root.startScan() }
                }
                Toggle { anchors.verticalCenter: undefined; checked: root.powered; enabled: !BtService.rfHard; onToggled: v => root.setPower(v) }
            }
        }

        Rectangle {
            visible: BtService.rfHard || root.powerError !== ""
            width: parent.width; height: visible ? bannerText.implicitHeight + 16 : 0; radius: 10
            color: Qt.rgba(0.88, 0.11, 0.14, 0.18)
            Text {
                id: bannerText
                anchors { fill: parent; margins: 8 }
                wrapMode: Text.Wrap; color: Theme.fg; font.pixelSize: 12
                text: BtService.rfHard ? "Bluetooth is blocked by a hardware switch or airplane mode." : root.powerError
            }
        }

        Column {
            visible: root.powered
            width: parent.width
            spacing: 8

            AdapterSection { width: parent.width }

            // transfers
            Column {
                visible: Agents.transfers.length > 0
                width: parent.width
                spacing: 6
                Text { text: "Transfers"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                Repeater {
                    model: Agents.transfers
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 52; radius: 12
                        color: Theme.surface
                        Column {
                            anchors { left: parent.left; leftMargin: 12; right: cancelBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 4
                            Text {
                                width: parent.width; elide: Text.ElideRight; color: Theme.fg; font.pixelSize: 12
                                text: (modelData.direction === "in" ? "↓ " : "↑ ") + modelData.name + " · " + modelData.device +
                                      (modelData.size ? " · " + BtUtil.formatBytes(modelData.transferred) + " / " + BtUtil.formatBytes(modelData.size) : "")
                            }
                            Rectangle {
                                width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.1)
                                Rectangle { height: parent.height; radius: 2; color: Theme.accent; width: modelData.size ? parent.width * modelData.transferred / modelData.size : 0 }
                            }
                        }
                        Rectangle {
                            id: cancelBtn
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            width: 24; height: 24; radius: 12
                            color: cm.containsMouse ? Theme.hover : "transparent"
                            Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted; font.pixelSize: 11 }
                            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; onClicked: Agents.send({ type: "cancel-transfer", path: modelData.path }) }
                        }
                    }
                }
            }

            Flickable {
                width: parent.width
                height: Math.min(list.implicitHeight, 420)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: list
                    width: parent.width
                    spacing: 6
                    Text {
                        visible: root.connectedList.length + root.pairedList.length + root.nearbyList.length === 0
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        topPadding: 20; bottomPadding: 20
                        text: root.adapter && root.adapter.discovering ? "Searching for devices…" : "No devices found"
                        color: Theme.muted; font.pixelSize: Theme.fontSize
                    }
                    component Section: Column {
                        property string title
                        property var items: []
                        visible: items.length > 0
                        width: parent.width
                        spacing: 6
                        Text { text: title; color: Theme.muted; font { pixelSize: 12; bold: true } }
                        Repeater {
                            model: items
                            DeviceRow {
                                required property var modelData
                                device: modelData
                                expandedAddress: root.expanded
                                onExpandRequested: a => root.expanded = a
                            }
                        }
                    }
                    Section { title: "Connected"; items: root.connectedList }
                    Section { title: "My Devices"; items: root.pairedList }
                    Section { title: "Nearby"; items: root.nearbyList }
                }
            }
        }

        // options
        Column {
            width: parent.width
            property bool open: false
            Rectangle {
                width: parent.width; height: 34; radius: 10
                color: om.containsMouse ? Theme.hover : "transparent"
                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Options"; color: Theme.accent; font { pixelSize: Theme.fontSize; bold: true } }
                Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } text: parent.parent.open ? "▴" : "▾"; color: Theme.accent; font.pixelSize: 12 }
                MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; onClicked: parent.parent.open = !parent.parent.open }
            }
            Column {
                visible: parent.open
                width: parent.width
                spacing: 4
                topPadding: 4
                Repeater {
                    model: [
                        { key: "notifyConnections", label: "Connection notifications" },
                        { key: "notifyLowBattery", label: "Low battery warnings" },
                        { key: "controllerWakelock", label: "Stay awake with game controller" },
                        { key: "acceptFromTrusted", label: "Auto-accept files from trusted devices" },
                        { key: "showUnnamed", label: "Show unnamed devices" }
                    ]
                    Rectangle {
                        required property var modelData
                        width: parent.width; height: 36; radius: 12
                        color: Theme.surface
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: Theme.fg; font.pixelSize: Theme.fontSize }
                        Toggle {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            checked: BtService.settings[modelData.key]
                            onToggled: v => { const p = {}; p[modelData.key] = v; BtService.update(p) }
                        }
                    }
                }
            }
        }
    }
}
