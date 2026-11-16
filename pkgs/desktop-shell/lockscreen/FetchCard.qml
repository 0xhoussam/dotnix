import QtQuick

// A neofetch-style summary: OS, window manager, user, uptime, battery.
Card {
    id: root
    implicitHeight: col.implicitHeight + 32

    readonly property var lines: {
        const l = [
            ["OS  ", Sys.osName],
            ["WM  ", Sys.wm],
            ["USER", Sys.user],
            ["UP  ", Sys.uptime || "…"]
        ]
        if (Sys.hasBattery) l.push(["BATT", (Sys.charging ? "(+) " : "") + Sys.battery + "%"])
        return l
    }

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 7

        Row {
            spacing: 10
            Rectangle {
                width: 26; height: 22; radius: 7
                color: Theme.cyan
                Text { anchors.centerIn: parent; text: ">"; color: Theme.bg; font { family: Theme.mono; pixelSize: 13; bold: true } }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "fetch"; color: Theme.fg; font { family: Theme.mono; pixelSize: 13; bold: true } }
        }
        Repeater {
            model: root.lines
            FadeText {
                required property var modelData
                width: col.width
                elide: Text.ElideRight
                text: modelData[0] + ": " + modelData[1]
                color: Theme.fg
                font { family: Theme.mono; pixelSize: 12 }
            }
        }
    }
}
