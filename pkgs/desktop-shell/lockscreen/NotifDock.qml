import QtQuick

// Notification history the shell saved. Titles only: a lock screen is
// visible to anyone nearby, so message bodies are never shown here.
Card {
    id: root
    clip: true
    readonly property var list: Sys.notifs

    function ago(ms) {
        const m = Math.floor((Date.now() - ms) / 60000)
        return m < 1 ? "now" : m < 60 ? m + "m" : m < 1440 ? Math.floor(m / 60) + "h" : Math.floor(m / 1440) + "d"
    }

    Text {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        text: root.list.length > 0 ? root.list.length + (root.list.length === 1 ? " NOTIFICATION" : " NOTIFICATIONS") : "NOTIFICATIONS"
        color: Theme.dim
        elide: Text.ElideRight
        font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 * Theme.ls }
    }

    Text {
        anchors.centerIn: parent
        text: "No notifications"
        color: Theme.dim
        opacity: root.list.length === 0 ? 1 : 0
        Behavior on opacity { Anim { kind: "slowEffects"; duration: 500 } }
        font { family: Theme.font; pixelSize: 12 }
    }

    ListView {
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; margins: 12; topMargin: 10 }
        clip: true
        spacing: 6
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: root.list
        add: Transition {
            ParallelAnimation {
                Anim { property: "opacity"; from: 0; to: 1; kind: "effects" }
                Anim { property: "x"; from: 24; kind: "emphasized" }
            }
        }
        displaced: Transition { Anim { property: "y"; kind: "emphasized" } }
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: row.implicitHeight + 16
            radius: 12
            color: Theme.card
            Column {
                id: row
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 2
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - ago.implicitWidth
                        text: (modelData.appName || "Notification").toUpperCase()
                        elide: Text.ElideRight
                        color: Theme.cyan
                        font { family: Theme.font; pixelSize: 9; weight: Font.Bold; letterSpacing: 1.5 * Theme.ls }
                    }
                    Text { id: ago; text: root.ago(modelData.time); color: Theme.dim; font { family: Theme.font; pixelSize: 9 } }
                }
                Text {
                    width: parent.width
                    visible: Sys.showNotifTitles
                    text: modelData.summary || ""
                    elide: Text.ElideRight
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 12; weight: Font.DemiBold }
                }
            }
        }
    }
}
