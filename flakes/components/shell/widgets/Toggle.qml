import QtQuick
import ".."

// Small pill switch.
Rectangle {
    id: root
    property bool checked: false
    property bool enabled: true
    signal toggled(bool value)
    implicitWidth: 38
    implicitHeight: 22
    radius: 11
    opacity: enabled ? 1 : 0.4
    color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.18)
    Behavior on color { ColorAnimation { duration: 140 } }
    Rectangle {
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        width: 18; height: 18; radius: 9
        color: "white"
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.toggled(!root.checked)
    }
}
