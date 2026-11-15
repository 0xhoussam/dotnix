import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../.."

// Battery icon + percentage. Hidden when no battery present.
Item {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev && dev.ready && dev.isLaptopBattery
    visible: present
    implicitWidth: present ? row.implicitWidth + 14 : 0
    implicitHeight: row.implicitHeight + 6

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: root.dev ? Quickshell.iconPath(root.dev.iconName, true) : ""
        }
        Text {
            text: root.dev ? Math.round(root.dev.percentage * 100) + "%" : ""
            color: Theme.muted
            font.pixelSize: Theme.fontSize
        }
    }
}
