import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../widgets"
import ".."

// "Connect to Hidden Wi-Fi Network…": SSID, security (open / WPA / WPA3
// personal) and password. Enterprise and WEP networks are set up in
// Network Settings.
Scope {
    id: root
    property var dev: null
    property bool shown: false
    property string security: "wpa-psk"
    property string error: ""
    property bool busy: false

    function openFor(d) { dev = d; error = ""; busy = false; ssid.text = ""; pw.text = ""; security = "wpa-psk"; shown = true }
    readonly property bool valid: ssid.text.length > 0 && ssid.text.length <= 32
        && (security === "none" || Validate.check(security === "sae" ? "nonempty" : "psk", pw.text) === null)

    function submit() {
        if (!valid || busy || !dev) return
        busy = true
        error = ""
        const settings = {
            connection: { type: "802-11-wireless", id: ssid.text },
            "802-11-wireless": { ssid: Array.from(new TextEncoder().encode(ssid.text)), hidden: true }
        }
        if (security !== "none") settings["802-11-wireless-security"] = { "key-mgmt": security, psk: pw.text }
        NetService.op("connect-new", { device: dev.path, ap: "/", settings: settings }, (ok, v) => {
            busy = false
            if (ok) shown = false
            else if (v !== "Cancelled") error = v
        })
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "net-join"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: 408
        implicitHeight: card.implicitHeight + 48
        mask: Region { item: card }

        Rectangle {
            id: card
            x: 24; y: 24
            width: 360
            implicitHeight: col.implicitHeight + 40
            radius: 18
            color: Theme.popoverBg
            border.color: Qt.rgba(1, 1, 1, 0.07)
            focus: true
            Keys.onEscapePressed: root.shown = false

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: 20 }
                spacing: 12

                Text { text: "Connect to Hidden Network"; color: Theme.fg; font { pixelSize: 16; bold: true } }
                Text { text: "Network name"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 38; radius: 19; color: Qt.rgba(1, 1, 1, 0.08)
                    TextInput {
                        id: ssid
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg; font.pixelSize: 15; maximumLength: 32
                        focus: root.shown
                        onAccepted: root.submit()
                    }
                }
                Text { text: "Security"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [["none", "Open"], ["wpa-psk", "WPA/WPA2"], ["sae", "WPA3"]]
                        Chip { required property var modelData; label: modelData[1]; active: root.security === modelData[0]; onClicked: root.security = modelData[0] }
                    }
                }
                ColumnLayout {
                    visible: root.security !== "none"
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "Password"; color: Theme.muted; font { pixelSize: 12; bold: true } }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 38; radius: 19; color: Qt.rgba(1, 1, 1, 0.08)
                        TextInput {
                            id: pw
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg; font.pixelSize: 15
                            echoMode: TextInput.Password; passwordCharacter: "●"
                            onAccepted: root.submit()
                        }
                    }
                }
                Text { Layout.fillWidth: true; visible: root.error !== ""; text: root.error; color: "#ff7b63"; font.pixelSize: 12; wrapMode: Text.Wrap }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Chip { Layout.fillWidth: true; implicitHeight: 36; label: "Cancel"; onClicked: root.shown = false }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 36; radius: 18
                        color: ok.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                        opacity: root.valid && !root.busy ? 1 : 0.6
                        Text { anchors.centerIn: parent; text: root.busy ? "Connecting…" : "Connect"; color: Theme.accentFg; font { bold: true; pixelSize: Theme.fontSize } }
                        MouseArea { id: ok; anchors.fill: parent; hoverEnabled: true; onClicked: root.submit() }
                    }
                }
            }
        }
    }
}
