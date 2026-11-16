import QtQuick
import Quickshell
import ".."
import "../motion"

// Quick-settings toggle tile: icon, label, optional sub-label.
Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    property bool enabled: true
    signal clicked()
    implicitHeight: 52
    radius: 14
    opacity: enabled ? 1 : 0.45
    color: active ? Theme.accentSoft : ma.containsMouse ? Theme.surfaceHover : Theme.surface
    Behavior on color { CAnim { kind: "fastEffects" } }
    Row {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 10
        Image {
            layer.enabled: true; layer.effect: Tint {}
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; sourceSize: Qt.size(36, 36)
            source: Quickshell.iconPath(root.icon, true)
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: root.label; color: Theme.fg; font { pixelSize: 12; bold: true } elide: Text.ElideRight; width: root.width - 56 }
            Text { visible: text !== ""; text: root.sub; color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight; width: root.width - 56 }
        }
    }
    Ripple { id: ripple; radius: root.radius }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled
        onPressed: mouse => ripple.press(mouse.x, mouse.y)
        onPressedChanged: ripple.pressed = pressed
        onClicked: root.clicked()
    }
}
