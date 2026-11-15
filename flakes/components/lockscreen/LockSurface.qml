import QtQuick
import "."

// One surface per monitor: wallpaper, a legibility scrim, then the clock
// (top-left), password field (right) and bottom bar on top.
Item {
    id: root
    opacity: Session.leaving ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 250 } }

    // any input resumes an idle-paused video
    HoverHandler { onPointChanged: Session.noteInput() }
    Keys.onPressed: event => { Session.noteInput(); event.accepted = false }

    Rectangle { anchors.fill: parent; color: "#0b0d12" }
    Background { anchors.fill: parent }
    // darken the edges where the text sits, keep the middle clean
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.45) }
            GradientStop { position: 0.28; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    Item {
        id: content
        anchors { fill: parent; leftMargin: 44; rightMargin: 44; bottomMargin: 26 }
        opacity: 0
        Component.onCompleted: show.start()
        NumberAnimation { id: show; target: content; property: "opacity"; to: 1; duration: 600; easing.type: Easing.OutCubic }

        Clock { anchors { left: parent.left; top: parent.top; topMargin: 30 } }
        LoginBox { anchors { right: parent.right; bottom: bottomBar.top; bottomMargin: 70 } }
        BottomBar { id: bottomBar; width: parent.width; anchors.bottom: parent.bottom }
    }
}
