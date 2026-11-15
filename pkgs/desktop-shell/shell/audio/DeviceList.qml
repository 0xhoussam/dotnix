import QtQuick
import "../widgets"
import ".."

// Collapsed to the current device; click to expand and pick another.
Column {
    id: root
    property var devices: []
    property var current: null
    property bool open: false
    signal picked(var node)
    spacing: 4

    Rectangle {
        width: parent.width; height: 32; radius: 10
        color: hm.containsMouse ? Theme.hover : Theme.surface
        Text {
            x: 12; width: parent.width - 48; anchors.verticalCenter: parent.verticalCenter
            text: root.current ? AudioService.deviceName(root.current) : "No device"
            color: Theme.fg; font.pixelSize: 12; elide: Text.ElideRight
        }
        Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: root.open ? "▴" : "▾"; color: Theme.muted; font.pixelSize: 12; visible: root.devices.length > 1 }
        MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; enabled: root.devices.length > 1; onClicked: root.open = !root.open }
    }
    Repeater {
        model: root.open ? root.devices : []
        Rectangle {
            required property var modelData
            readonly property bool isCurrent: modelData === root.current
            width: root.width; height: 30; radius: 10
            color: isCurrent ? Theme.accentSoft : dm.containsMouse ? Theme.hover : Theme.surfaceFaint
            Text { x: 12; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter; text: AudioService.deviceName(modelData); color: Theme.fg; font.pixelSize: 12; elide: Text.ElideRight }
            Text { visible: parent.isCurrent; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "✓"; color: Theme.accent; font.pixelSize: 12 }
            MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; onClicked: { root.picked(modelData); root.open = false } }
        }
    }
}
