import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../bar/items"
import "../widgets"
import ".."

// Network indicator + popup with nm-applet's feature set: Wi-Fi (per
// adapter) with saved/other networks, hidden networks, wired / mobile /
// Bluetooth devices, VPN, connection information, notifications.
Pill {
    id: root
    readonly property var n: Agents.net
    readonly property bool nmRunning: n ? n.nmRunning : false
    readonly property bool networking: n ? n.networking : false
    readonly property bool ready: nmRunning && networking
    readonly property bool hasWifi: n ? n.wifi.length > 0 : false
    property string expanded: ""
    property bool scanning: false
    property bool hoverList: false

    active: pop.visible
    onClicked: pop.visible = !pop.visible

    Row {
        spacing: 2
        Image { layer.enabled: true; layer.effect: Tint {}
            width: 16; height: 16; sourceSize: Qt.size(32, 32)
            source: Quickshell.iconPath(root.n ? root.n.icon : "network-error-symbolic", true)
        }
        Image { layer.enabled: true; layer.effect: Tint {}
            visible: root.n && root.n.vpnActive
            anchors.bottom: parent.bottom
            width: 11; height: 11; sourceSize: Qt.size(22, 22)
            source: Quickshell.iconPath("network-vpn-symbolic", true)
        }
    }

    // ---- scanning ----
    function scan() {
        if (!n || !n.wifiEnabled || !n.wifi.length) return
        scanning = true
        NetService.op("scan", { devices: n.wifi.map(d => d.path) })
        scanTimer.restart()
    }
    Timer { id: scanTimer; interval: 10000; onTriggered: root.scanning = false }

    // ---- stable ordering while the pointer is over the list / a row is open ----
    property var view: []
    readonly property bool hold: hoverList || expanded !== ""
    function keysOf(devs) {
        const k = []
        for (const d of devs) { if (d.active) k.push(d.path + d.active.key); for (const x of d.saved.concat(d.other)) k.push(d.path + x.key) }
        return k.sort().join("|")
    }
    // Same networks as before: keep the old order, take the new data.
    function reorder(next, old) {
        return next.map((d, i) => {
            const o = old.find(x => x.path === d.path)
            if (!o) return d
            const byKey = {}
            for (const x of d.saved.concat(d.other)) byKey[x.key] = x
            const pick = list => list.map(x => byKey[x.key]).filter(x => x)
            return Object.assign({}, d, { saved: pick(o.saved), other: pick(o.other) })
        })
    }
    function refreshView() {
        if (!n) return
        if (hold && view.length && keysOf(view) === keysOf(n.wifi)) view = reorder(n.wifi, view)
        else view = n.wifi
    }
    onNChanged: refreshView()
    onHoldChanged: if (!hold) refreshView()

    // our dialogs need the keyboard: get the popup out of the way
    Connections {
        target: Agents
        function onCurrentChanged() { if (Agents.current && Agents.current.prompt.kind === "secrets") pop.visible = false }
    }

    // Close when clicking anywhere else (the bar itself stays interactive).
    HyprlandFocusGrab {
        windows: [pop, QsWindow.window]
        active: pop.visible
        onCleared: pop.visible = false
    }

    PopupWindow {
        id: pop
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        implicitWidth: 392
        implicitHeight: card.implicitHeight
        color: "transparent"
        onVisibleChanged: {
            UiState.openPopups += visible ? 1 : -1
            if (visible) root.scan()
        }

        Rectangle {
            id: card
            width: parent.width
            implicitHeight: col.implicitHeight + 24
            radius: 16
            color: Theme.popoverBg
            border.color: Qt.rgba(1, 1, 1, 0.07)

            Column {
                id: col
                x: 16; y: 12
                width: parent.width - 32
                spacing: 8

                // header
                Item {
                    width: parent.width; height: 28
                    Text { text: root.hasWifi ? "Wi-Fi" : "Network"; color: Theme.fg; font { pixelSize: 16; bold: true } anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            visible: root.scanning && root.n && root.n.wifiEnabled
                            text: "⟳"; color: Theme.muted; font.pixelSize: 16
                            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.visible }
                        }
                        Rectangle {
                            visible: root.hasWifi && root.n.wifiEnabled && !root.scanning && root.ready
                            width: 26; height: 26; radius: 13
                            color: sc.containsMouse ? Theme.hover : "transparent"
                            Text { anchors.centerIn: parent; text: "↻"; color: Theme.muted; font.pixelSize: 15 }
                            MouseArea { id: sc; anchors.fill: parent; hoverEnabled: true; onClicked: root.scan() }
                        }
                        Toggle {
                            visible: root.hasWifi
                            checked: root.n ? root.n.wifiEnabled : false
                            enabled: root.n && root.n.wifiHw && root.ready
                            onToggled: v => NetService.op("set-wifi", { on: v })
                        }
                    }
                }

                // banner
                Rectangle {
                    readonly property string text: !root.nmRunning ? "NetworkManager is not running."
                        : !root.networking ? "Networking is disabled."
                        : root.hasWifi && !root.n.wifiHw ? "Wi-Fi is disabled by a hardware switch or airplane mode." : ""
                    visible: text !== ""
                    width: parent.width; height: visible ? Math.max(bt.implicitHeight, 28) + 16 : 0; radius: 10
                    color: Qt.rgba(0.88, 0.11, 0.14, 0.18)
                    Text { id: bt; anchors { left: parent.left; leftMargin: 10; right: en.left; rightMargin: 8; verticalCenter: parent.verticalCenter } wrapMode: Text.Wrap; color: Theme.fg; font.pixelSize: 12; text: parent.text }
                    Chip { id: en; visible: root.nmRunning && !root.networking; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } label: "Enable"; onClicked: NetService.op("set-networking", { on: true }) }
                }

                // captive portal
                Rectangle {
                    visible: root.n && root.n.connectivity === 2
                    width: parent.width; height: visible ? 40 : 0; radius: 10
                    color: Qt.rgba(0.21, 0.52, 0.89, 0.22)
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "This network requires you to sign in."; color: Theme.fg; font.pixelSize: 12 }
                    Chip { anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } label: "Sign In"; onClicked: Quickshell.execDetached(["xdg-open", "http://nmcheck.gnome.org/"]) }
                }

                Flickable {
                    visible: root.ready
                    width: parent.width
                    height: Math.min(body.implicitHeight, 620)
                    contentHeight: body.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: body
                        width: parent.width
                        spacing: 10

                        Column {
                            visible: root.hasWifi && root.n.wifiEnabled
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: root.view
                                Column {
                                    id: wd
                                    required property var modelData
                                    width: body.width
                                    spacing: 6
                                    HoverHandler { onHoveredChanged: root.hoverList = hovered }
                                    Text { visible: root.view.length > 1; text: wd.modelData.name; color: Theme.fg; font { pixelSize: 12; bold: true } }
                                    Rectangle {
                                        visible: !!wd.modelData.unusable
                                        width: parent.width; height: visible ? 36 : 0; radius: 10
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: wd.modelData.unusable || ""; color: Theme.fg; font.pixelSize: 12 }
                                    }
                                    // running hotspot
                                    Column {
                                        visible: !!wd.modelData.hotspot
                                        width: parent.width
                                        OpState { id: hops }
                                        property bool hopen: false
                                        ListRow {
                                            width: parent.width
                                            icon: "network-wireless-hotspot-symbolic"
                                            title: wd.modelData.hotspot ? (wd.modelData.hotspot.ssid || "Hotspot") : ""
                                            status: hops.error || hops.busy || "Hotspot active"
                                            active: true
                                            expandable: false
                                            onClicked: parent.hopen = !parent.hopen
                                            trailing: [ Chip { label: "Stop"; onClicked: hops.run("Stopping…", cb => NetService.op("deactivate", { ac: wd.modelData.hotspot.ac }, cb)) } ]
                                        }
                                        InfoBlock { visible: parent.hopen; width: parent.width; groups: wd.modelData.hotspot ? wd.modelData.hotspot.info : [] }
                                    }
                                    Column {
                                        visible: !wd.modelData.unusable && !wd.modelData.hotspot
                                        width: parent.width
                                        spacing: 6
                                        Text {
                                            visible: !wd.modelData.active && wd.modelData.saved.length + wd.modelData.other.length === 0
                                            width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 20; bottomPadding: 20
                                            text: root.scanning ? "Searching for networks…" : "No networks found"
                                            color: Theme.muted; font.pixelSize: Theme.fontSize
                                        }
                                        component Section: Column {
                                            property string title
                                            property var items: []
                                            property bool activeSection: false
                                            visible: items.length > 0
                                            width: parent.width
                                            spacing: 6
                                            Text { text: title; color: Theme.muted; font { pixelSize: 12; bold: true } }
                                            Repeater {
                                                model: items
                                                NetRow {
                                                    required property var modelData
                                                    net: modelData
                                                    dev: wd.modelData
                                                    isActive: activeSection
                                                    expandedKey: root.expanded
                                                    onExpandRequested: k => root.expanded = k
                                                }
                                            }
                                        }
                                        Section { title: "Connected"; activeSection: true; items: wd.modelData.active ? [wd.modelData.active] : [] }
                                        Section { title: "Saved Networks"; items: wd.modelData.saved }
                                        Section { title: "Other Networks"; items: wd.modelData.other }
                                    }
                                }
                            }
                            Chip {
                                width: parent.width
                                label: "Hidden Network…"
                                onClicked: { pop.visible = false; join.openFor(root.n.wifi[0]) }
                            }
                        }

                        // wired / mobile / bluetooth devices
                        Column {
                            visible: root.n && root.n.devices.length > 0
                            width: parent.width
                            spacing: 6
                            Text { text: root.n && root.n.devices.every(d => d.kind === "ethernet") ? "Wired" : "Devices"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                            Repeater {
                                model: root.n ? root.n.devices : []
                                DeviceCard {
                                    required property var modelData
                                    dev: modelData
                                    expandedKey: root.expanded
                                    onExpandRequested: k => root.expanded = k
                                }
                            }
                        }

                        // VPN
                        Column {
                            width: parent.width
                            spacing: 6
                            Row {
                                width: parent.width
                                Text { text: "VPN"; color: Theme.muted; font { pixelSize: 12; bold: true } width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter }
                                Chip { label: "+"; padX: 9; onClicked: Quickshell.execDetached(["nm-connection-editor", "--create", "--type", "vpn"]) }
                                Chip { label: "⚙"; padX: 9; onClicked: Quickshell.execDetached(["nm-connection-editor", "--show", "--type", "vpn"]) }
                            }
                            Text { visible: root.n && root.n.vpns.length === 0; text: "No VPN connections configured"; color: Theme.muted; font.pixelSize: 12 }
                            Repeater {
                                model: root.n ? root.n.vpns : []
                                VpnRow {
                                    required property var modelData
                                    vpn: modelData
                                    expandedKey: root.expanded
                                    onExpandRequested: k => root.expanded = k
                                }
                            }
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
                        component Opt: Rectangle {
                            property string label
                            property bool checked
                            property bool enabled: true
                            signal toggled(bool v)
                            width: parent.width; height: 36; radius: 12
                            color: Qt.rgba(1, 1, 1, 0.05)
                            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: label; color: Theme.fg; font.pixelSize: Theme.fontSize }
                            Toggle { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } checked: parent.checked; enabled: parent.enabled; onToggled: v => parent.toggled(v) }
                        }
                        Opt { label: "Enable networking"; checked: root.networking; onToggled: v => NetService.op("set-networking", { on: v }) }
                        Opt { visible: root.n && root.n.hasModem; height: visible ? 36 : 0; label: "Enable mobile broadband"; checked: root.n ? root.n.wwanEnabled : false; enabled: root.n && root.n.wwanHw; onToggled: v => NetService.op("set-wwan", { on: v }) }
                        Opt { label: "Connection notifications"; checked: NetService.settings.notifyConnected; onToggled: v => NetService.update({ notifyConnected: v }) }
                        Opt { label: "Disconnect / failure notifications"; checked: NetService.settings.notifyDisconnected; onToggled: v => NetService.update({ notifyDisconnected: v }) }
                        Opt { label: "VPN notifications"; checked: NetService.settings.notifyVpn; onToggled: v => NetService.update({ notifyVpn: v }) }
                    }
                }

                Rectangle {
                    width: parent.width; height: 34; radius: 10
                    color: ns.containsMouse ? Theme.hover : "transparent"
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Network Settings…"; color: Theme.accent; font { pixelSize: Theme.fontSize; bold: true } }
                    MouseArea { id: ns; anchors.fill: parent; hoverEnabled: true; onClicked: { pop.visible = false; Quickshell.execDetached(["nm-connection-editor"]) } }
                }
            }
        }
    }

    JoinDialog { id: join }
}
