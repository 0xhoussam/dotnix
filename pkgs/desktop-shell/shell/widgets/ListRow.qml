import QtQuick
import Quickshell
import ".."
import "../motion"

// Boxed-list row: icon, title, status line, optional spinner / lock / check,
// and an expand chevron. Shared by the network panel rows.
Rectangle {
    id: root
    property string icon: ""
    property string title: ""
    property string status: ""
    property bool active: false
    property bool isError: false
    property bool working: false
    property bool open: false
    property bool secured: false
    property bool check: false
    property bool expandable: true
    property bool enabled: true
    property alias trailing: trail.data
    signal clicked()
    signal expandClicked()

    implicitHeight: 50
    radius: 12
    opacity: enabled ? 1 : 0.5
    color: active ? Theme.accentSoft : main.containsMouse ? Theme.surfaceHover : Theme.surface
    Behavior on color { CAnim { kind: "fastEffects" } }
    // square off the bottom corners while the details panel is open
    Rectangle { visible: root.open; anchors.bottom: parent.bottom; width: parent.width; height: parent.radius; color: parent.color }

    Ripple { id: ripple; radius: root.radius; anchors.rightMargin: root.expandable || trail.children.length ? 40 : 0 }
    MouseArea {
        id: main; anchors { fill: parent; rightMargin: root.expandable || trail.children.length ? 40 : 0 }
        hoverEnabled: true; enabled: root.enabled
        onPressed: mouse => ripple.press(mouse.x, mouse.y)
        onPressedChanged: ripple.pressed = pressed
        onClicked: root.clicked()
    }

    Row {
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 10
        Image { layer.enabled: true; layer.effect: Tint {}
            anchors.verticalCenter: parent.verticalCenter
            width: 17; height: 17; sourceSize: Qt.size(34, 34)
            source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: root.title; color: Theme.fg; font { pixelSize: Theme.fontSize; bold: true } elide: Text.ElideRight; width: 210 }
            Text { text: root.status; color: root.isError ? Theme.danger : (root.active ? Theme.textDim : Theme.muted); font.pixelSize: 11; elide: Text.ElideRight; width: 210 }
        }
    }
    Row {
        anchors { right: parent.right; rightMargin: root.expandable ? 40 : 12; verticalCenter: parent.verticalCenter }
        spacing: 8
        Text {
            visible: root.working
            text: "⟳"; color: Theme.muted; font.pixelSize: 16
            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: parent.visible }
        }
        Image { layer.enabled: true; layer.effect: Tint {}
            visible: root.secured
            anchors.verticalCenter: parent.verticalCenter
            width: 13; height: 13; sourceSize: Qt.size(26, 26)
            source: Quickshell.iconPath("network-wireless-encrypted-symbolic", true)
            opacity: 0.6
        }
        Text { visible: root.check; text: "✓"; color: Theme.accent; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        Row { id: trail; spacing: 6; anchors.verticalCenter: parent.verticalCenter }
    }
    Rectangle {
        visible: root.expandable
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        width: 28; height: 28; radius: 14
        color: chev.containsMouse ? Theme.hover : "transparent"
        Text { anchors.centerIn: parent; text: root.open ? "▴" : "▾"; color: Theme.muted; font.pixelSize: 12 }
        MouseArea { id: chev; anchors.fill: parent; hoverEnabled: true; onClicked: root.expandClicked() }
    }
}
