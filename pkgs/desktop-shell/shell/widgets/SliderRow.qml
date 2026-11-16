import QtQuick
import Quickshell
import ".."

// Labelled slider row: icon, label, value text, slider underneath.
Column {
    id: root
    property string icon: ""
    property string label: ""
    property string valueText: ""
    property real value: 0
    property real to: 1
    property real step: 0.05
    signal moved(real value)

    spacing: 6
    Row {
        width: parent.width
        spacing: 8
        Image {
            layer.enabled: true; layer.effect: Tint {}
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16; sourceSize: Qt.size(32, 32)
            source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 16 - 8 - vt.implicitWidth - 8
            text: root.label; color: Theme.fg; elide: Text.ElideRight
            font { pixelSize: 12; bold: true }
        }
        Text { id: vt; anchors.verticalCenter: parent.verticalCenter; text: root.valueText; color: Theme.muted; font.pixelSize: 12 }
    }
    Slider {
        width: parent.width
        to: root.to
        step: root.step
        value: root.value
        onMoved: v => root.moved(v)
    }
}
