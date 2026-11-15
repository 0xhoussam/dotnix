import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import ".."

// One notification card. Used in the panel list and as a popup toast.
Rectangle {
    id: card
    required property var n
    property bool toast: false

    implicitWidth: toast ? 360 : 380
    implicitHeight: col.implicitHeight + 20
    radius: 12
    color: toast ? Theme.popoverBg : Theme.card
    border.width: n.urgency === NotificationUrgency.Critical ? 1 : (toast ? 1 : 0)
    border.color: n.urgency === NotificationUrgency.Critical ? Qt.rgba(1, 0.48, 0.39, 0.6) : Qt.rgba(1, 1, 1, 0.08)

    function iconSrc(v) {
        if (!v) return ""
        return v.startsWith("/") || v.startsWith("file:") || v.startsWith("image:") ? v : Quickshell.iconPath(v, true)
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 10; leftMargin: 12; rightMargin: 12 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Image {
                Layout.preferredWidth: 16; Layout.preferredHeight: 16
                sourceSize: Qt.size(32, 32)
                source: card.iconSrc(card.n.appIcon || card.n.desktopEntry || "dialog-information-symbolic")
            }
            Text {
                text: card.n.appName || "Notification"
                color: Theme.muted; font.pixelSize: 12; font.bold: true
            }
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: Qt.formatDateTime(Notifs.arrived[card.n.id] || new Date(), "HH:mm")
                color: Theme.faint; font.pixelSize: 12
            }
            Rectangle {
                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                radius: 9
                color: closeArea.containsMouse ? Theme.hover : "transparent"
                Image { layer.enabled: true; layer.effect: Tint {}
                    anchors.centerIn: parent
                    width: 14; height: 14
                    sourceSize: Qt.size(28, 28)
                    source: Quickshell.iconPath("window-close-symbolic", true)
                }
                MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: card.n.dismiss() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Image {
                visible: !!card.n.image
                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                sourceSize: Qt.size(84, 84)
                fillMode: Image.PreserveAspectFit
                source: card.iconSrc(card.n.image)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.n.summary
                    color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!card.n.body
                    text: card.n.body
                    textFormat: Text.StyledText
                    color: Theme.muted; font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 6
            // Skip the implicit "default" action and blank labels.
            Repeater {
                model: card.n.actions.filter(a => a.identifier !== "default" && a.text && a.text.trim())
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 8
                    color: actArea.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: modelData.text; color: Theme.fg; font.pixelSize: Theme.fontSize }
                    MouseArea { id: actArea; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.invoke() }
                }
            }
        }
    }
}
