import QtQuick
import Quickshell
import ".."
import "../motion"

// Rounded text/icon button used across the panels.
Rectangle {
    id: root
    property string label: ""
    property string icon: ""
    property bool active: false
    property bool destructive: false
    property bool confirm: false
    property alias content: extra.data
    property int padX: 12
    signal clicked()
    implicitWidth: row.implicitWidth + padX * 2
    implicitHeight: 28
    radius: height / 2
    color: confirm ? Theme.dangerBg
        : active ? Theme.accentSoft
        : ma.containsMouse ? Theme.hover : Theme.card
    Behavior on color { CAnim { kind: "fastEffects" } }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Image {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; sourceSize: Qt.size(28, 28)
            source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
            layer.enabled: true; layer.effect: Tint {}
        }
        Item { id: extra; width: childrenRect.width; height: childrenRect.height; anchors.verticalCenter: parent.verticalCenter; visible: children.length > 0 }
        Text {
            visible: root.label !== ""
            text: root.label
            color: root.confirm ? "white" : root.destructive ? Theme.danger : Theme.fg
            font.pixelSize: 12
            font.bold: true
        }
    }
    Ripple { id: ripple; radius: root.radius }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        onPressed: mouse => ripple.press(mouse.x, mouse.y)
        onPressedChanged: ripple.pressed = pressed
        onClicked: root.clicked()
    }
}
