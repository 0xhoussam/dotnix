import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../.."

// StatusNotifierItem tray. Left click activates, middle secondary-activates,
// right click opens the dbusmenu.
Row {
    spacing: 0
    visible: SystemTray.items.values.length > 0
    Repeater {
        model: SystemTray.items
        Rectangle {
            id: cell
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            width: 16 + 10; height: 16 + 6
            radius: Theme.radius
            color: area.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Image {
                anchors.centerIn: parent
                width: 16; height: 16
                sourceSize: Qt.size(32, 32)
                source: cell.modelData.icon
            }
            QsMenuAnchor {
                id: menu
                menu: cell.modelData.menu
                anchor.item: cell
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
                onVisibleChanged: UiState.openPopups += visible ? 1 : -1
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) cell.modelData.secondaryActivate()
                    else if (mouse.button === Qt.RightButton && cell.modelData.hasMenu) menu.open()
                    else if (cell.modelData.onlyMenu && cell.modelData.hasMenu) menu.open()
                    else cell.modelData.activate()
                }
            }
        }
    }
}
