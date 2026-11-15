import QtQuick
import ".."
import "../.."

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
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Item {
        id: holder
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.scrolled(wheel)
    }
}
