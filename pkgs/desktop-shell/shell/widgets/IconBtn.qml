import QtQuick
import Quickshell
import ".."
import "../motion"

// Round icon-only button. `confirm` turns it red (an armed destructive action).
Rectangle {
    id: root
    // One icon name, or several separated by commas: the first one the icon
    // theme has is used (themes differ in which symbolic icons they ship).
    property string icon: ""
    readonly property string iconPath: {
        for (const n of icon.split(",")) {
            const p = Quickshell.iconPath(n.trim(), true)
            if (p) return p
        }
        return ""
    }
    property bool destructive: false
    property bool confirm: false
    property alias hovered: ma.containsMouse
    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    radius: confirm || ma.containsMouse ? 10 : height / 2
    color: confirm ? Theme.dangerBg : ma.containsMouse ? Theme.surfaceHover : Theme.surface
    scale: ma.pressed ? 0.92 : 1
    Behavior on radius { Anim { kind: "fastSpatial" } }
    Behavior on color { CAnim { kind: "fastEffects" } }
    Behavior on scale { Anim { kind: "fastSpatial" } }

    Ripple { id: ripple; radius: root.radius }
    Image {
        anchors.centerIn: parent
        width: 16; height: 16; sourceSize: Qt.size(32, 32)
        source: root.iconPath
        layer.enabled: true; layer.effect: Tint {}
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => ripple.press(mouse.x, mouse.y)
        onPressedChanged: ripple.pressed = pressed
        onClicked: root.clicked()
    }
}
