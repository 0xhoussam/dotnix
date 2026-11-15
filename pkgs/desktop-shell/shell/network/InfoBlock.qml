import QtQuick
import Quickshell.Io
import "../widgets"
import ".."

// "Connection Information" groups (general, IPv4, IPv6) for one active
// connection, with a Copy button.
Column {
    id: root
    property var groups: []
    spacing: 3
    Repeater {
        model: root.groups
        Column {
            required property var modelData
            width: root.width
            spacing: 3
            Text { text: modelData.title; color: Theme.muted; font { pixelSize: 11; bold: true } topPadding: 4 }
            Repeater {
                model: modelData.rows
                Row {
                    required property var modelData
                    spacing: 12
                    Text { text: modelData[0]; color: Theme.muted; font.pixelSize: 11; width: 100 }
                    Text { text: modelData[1]; color: Theme.fg; font { pixelSize: 11; family: "monospace" } width: root.width - 112; wrapMode: Text.WrapAnywhere }
                }
            }
        }
    }
    Process { id: copy }
    Chip {
        anchors.right: parent.right
        visible: root.groups.length > 0
        label: "Copy"
        onClicked: copy.exec(["wl-copy", root.groups.map(g => "[" + g.title + "]\n" + g.rows.map(r => r[0] + ": " + r[1]).join("\n")).join("\n\n")])
    }
}
