import QtQuick
import ".."
import "../.."
import "../../motion"

// Shared flat hover button (the `.modules-end button` style from SCSS).
Rectangle {
    id: root
    default property alias content: holder.data
    property bool active: false
    signal clicked(var mouse)
    signal scrolled(var wheel)

    implicitWidth: holder.implicitWidth + 14
    implicitHeight: holder.implicitHeight + 6
    radius: Theme.radius
    color: area.containsMouse || active ? Theme.hover : "transparent"
    scale: area.pressed ? 0.94 : 1
    Behavior on color { CAnim { kind: "fastEffects" } }
    Behavior on scale { Anim { kind: "fastSpatial" } }

    Item {
        id: holder
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
    Ripple { id: ripple; radius: root.radius }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: mouse => ripple.press(mouse.x, mouse.y)
        onPressedChanged: ripple.pressed = pressed
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.scrolled(wheel)
    }
}
