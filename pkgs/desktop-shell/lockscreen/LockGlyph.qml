import QtQuick

// A padlock drawn from rectangles (no icon theme needed): the closed state
// the panel starts from and returns to on unlock.
Item {
    id: root
    property color color: Theme.fg
    implicitWidth: 56
    implicitHeight: 64
    // shackle: a ring whose lower half hides behind the body
    Rectangle {
        x: 11; y: 2
        width: 34; height: 40
        radius: 17
        color: "transparent"
        border.width: 6
        border.color: root.color
    }
    Rectangle {
        y: 26
        width: parent.width; height: 38
        radius: 9
        color: root.color
        Rectangle {
            anchors.centerIn: parent
            width: 8; height: 14; radius: 4
            color: Theme.bg
        }
    }
}
