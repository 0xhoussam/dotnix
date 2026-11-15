import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../widgets"
import ".."

// NetworkManager secrets prompt (Wi-Fi password, 802.1X, VPN, PPPoE, SIM
// PIN, ...), rendered from the sidecar's "secrets" prompt.
Scope {
    id: root
    readonly property var cur: Agents.current
    readonly property var prompt: cur && cur.prompt.kind === "secrets" ? cur.prompt : null
    property var values: ({})
    property bool tried: false
    onPromptChanged: { values = {}; tried = false }

    function error(f) { return Validate.check(f.validate, values[f.key] || "") }
    readonly property bool valid: prompt !== null && prompt.fields.every(f => !error(f))
    function submit() {
        tried = true
        if (!valid) return
        const out = {}
        for (const f of prompt.fields) out[f.key] = values[f.key] || ""
        Agents.fields(out)
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: root.prompt !== null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "net-secrets"
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
            Keys.onEscapePressed: Agents.reject()

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: 20 }
                spacing: 14

                RowLayout {
                    spacing: 12
                    Image {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        sourceSize: Qt.size(64, 64)
                        source: Quickshell.iconPath(root.prompt ? root.prompt.icon : "dialog-password-symbolic", true)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.prompt ? root.prompt.title : ""
                        color: Theme.fg; font { pixelSize: 16; bold: true }
                        wrapMode: Text.Wrap
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.prompt && root.prompt.note
                    text: root.prompt && root.prompt.note ? root.prompt.note : ""
                    color: "#ff7b63"; font.pixelSize: 12; wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: root.prompt ? root.prompt.message : ""
                    color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: Theme.fontSize; wrapMode: Text.Wrap
                }

                Repeater {
                    model: root.prompt ? root.prompt.fields : []
                    ColumnLayout {
                        id: fld
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: modelData.label; color: Theme.muted; font { pixelSize: 12; bold: true } }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 38; radius: 19
                            color: Qt.rgba(1, 1, 1, 0.08)
                            TextInput {
                                id: input
                                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.fg; font.pixelSize: 15
                                echoMode: modelData.password ? TextInput.Password : TextInput.Normal
                                passwordCharacter: "●"
                                Component.onCompleted: { text = modelData.value || ""; root.values[modelData.key] = text; if (index === 0) forceActiveFocus() }
                                onTextChanged: { root.values[modelData.key] = text; root.valuesChanged() }
                                onAccepted: root.submit()
                            }
                        }
                        Text {
                            visible: root.tried && !!root.error(modelData)
                            text: root.error(modelData) || ""
                            color: "#ff7b63"; font.pixelSize: 11; wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Chip { Layout.fillWidth: true; implicitHeight: 36; label: "Cancel"; onClicked: Agents.reject() }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 36; radius: 18
                        color: ok.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
                        opacity: root.valid ? 1 : 0.6
                        Text { anchors.centerIn: parent; text: "Connect"; color: Theme.accentFg; font { bold: true; pixelSize: Theme.fontSize } }
                        MouseArea { id: ok; anchors.fill: parent; hoverEnabled: true; onClicked: root.submit() }
                    }
                }
            }
        }
    }
}
