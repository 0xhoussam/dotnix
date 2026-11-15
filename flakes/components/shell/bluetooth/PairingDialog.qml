import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../widgets"

// Centered overlay that renders the pending agent prompt (pairing PIN /
// passkey / confirmation, service authorization). Port of PairingDialog.tsx.
Scope {
    id: root
    readonly property var cur: Agents.current
    readonly property var prompt: cur ? cur.prompt : null
    readonly property bool needsKeyboard: prompt !== null && (prompt.kind === "pin" || prompt.kind === "passkey")

    function fmtPasskey(n) {
        const s = String(n).padStart(6, "0")
        return s.slice(0, 3) + " " + s.slice(3)
    }
    function title(p) {
        switch (p.kind) {
        case "authorize": return "Allow Pairing?"
        case "service": return "Allow Connection?"
        case "file": return "Incoming File"
        default: return "Pairing Request"
        }
    }
    function message(p, name) {
        switch (p.kind) {
        case "pin": return "Enter the PIN code for " + name + ". Simple devices often use 0000 or 1234."
        case "passkey": return "Enter the 6-digit passkey shown on " + name + "."
        case "confirm": return "Confirm that " + name + " shows the same passkey."
        case "show-pin": return "Type this PIN on " + name + ", then press Enter on it."
        case "show-passkey": return "Type this passkey on " + name + ", then press Enter on it."
        case "authorize": return name + " wants to pair with this computer."
        case "service": return name + " wants to use " + BtUtil.serviceName(p.uuid) + "."
        case "file": return name + " wants to send you a file."
        }
        return ""
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        visible: root.prompt !== null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "bt-pairing"
        WlrLayershell.keyboardFocus: root.needsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
        implicitWidth: 408
        implicitHeight: card.implicitHeight + 48
        // Centered: no anchors -> compositor centers the surface.
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
            Keys.onEscapePressed: Agents.reject()

            readonly property var dev: root.prompt ? BtUtil.deviceByPath(root.prompt.path) : null
            readonly property string devName: root.prompt ? BtUtil.displayName(dev, BtUtil.pathToAddress(root.prompt.path)) : ""

            function submit() {
                const t = field.text.trim()
                if (root.prompt.kind === "pin" && t) Agents.text(t)
                if (root.prompt.kind === "passkey" && /^\d{1,6}$/.test(t)) Agents.number(parseInt(t, 10))
            }

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: 20 }
                spacing: 14

                RowLayout {
                    spacing: 12
                    Image { layer.enabled: true; layer.effect: Tint {}
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        sourceSize: Qt.size(64, 64)
                        source: Quickshell.iconPath(card.dev ? BtUtil.deviceIcon(card.dev) : "bluetooth-active-symbolic", true)
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: root.prompt ? root.title(root.prompt) : ""; color: Theme.fg; font.pixelSize: 16; font.bold: true }
                        Text { text: card.devName; color: Theme.muted; font.pixelSize: 12; elide: Text.ElideRight; Layout.maximumWidth: 260 }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.prompt ? root.message(root.prompt, card.devName) : ""
                    color: Qt.rgba(1, 1, 1, 0.85)
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    visible: root.prompt !== null && ["confirm", "show-pin", "show-passkey"].includes(root.prompt.kind)
                    Layout.topMargin: 6; Layout.bottomMargin: 6
                    textFormat: Text.StyledText
                    font { pixelSize: 34; bold: true; family: "monospace"; letterSpacing: 4 }
                    color: Theme.fg
                    text: {
                        const p = root.prompt
                        if (!p) return ""
                        if (p.kind === "confirm") return root.fmtPasskey(p.passkey)
                        if (p.kind === "show-pin") return p.pin
                        // dim the digits the remote side has already typed
                        const s = root.fmtPasskey(p.passkey)
                        const n = p.entered + (p.entered > 3 ? 1 : 0)
                        return "<font color='#73ffffff'>" + s.slice(0, n) + "</font>" + s.slice(n)
                    }
                }

                Rectangle {
                    visible: root.needsKeyboard
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.08)
                    TextInput {
                        id: field
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        font { pixelSize: 15; family: "monospace" }
                        maximumLength: root.prompt && root.prompt.kind === "pin" ? 16 : 6
                        inputMethodHints: root.prompt && root.prompt.kind === "pin" ? Qt.ImhNone : Qt.ImhDigitsOnly
                        focus: visible
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                        onAccepted: card.submit()
                        Text {
                            visible: !field.text
                            text: root.prompt && root.prompt.kind === "pin" ? "PIN code" : "000000"
                            color: Theme.faint; font: field.font
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    component Btn: Rectangle {
                        id: b
                        property string label
                        property bool suggested: false
                        signal clicked()
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: 18
                        color: ma.containsMouse ? (suggested ? Qt.lighter(Theme.accent, 1.1) : Theme.hover) : (suggested ? Theme.accent : Theme.card)
                        Text { anchors.centerIn: parent; text: b.label; color: b.suggested ? Theme.accentFg : Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
                    }
                    readonly property string kind: root.prompt ? root.prompt.kind : ""
                    Btn { visible: ["pin", "passkey", "confirm", "show-pin", "show-passkey"].includes(parent.kind); label: "Cancel"; onClicked: Agents.reject() }
                    Btn { visible: ["pin", "passkey"].includes(parent.kind); label: "Pair"; suggested: true; onClicked: card.submit() }
                    Btn { visible: parent.kind === "confirm"; label: "Pair"; suggested: true; onClicked: Agents.yes() }
                    Btn { visible: ["authorize", "service"].includes(parent.kind); label: "Reject"; onClicked: Agents.reject() }
                    Btn { visible: parent.kind === "authorize"; label: "Allow"; suggested: true; onClicked: Agents.yes() }
                    Btn { visible: parent.kind === "service"; label: "Allow once"; onClicked: Agents.yes() }
                    Btn { visible: parent.kind === "service"; label: "Always"; suggested: true; onClicked: Agents.always() }
                }
            }
        }
    }
}
