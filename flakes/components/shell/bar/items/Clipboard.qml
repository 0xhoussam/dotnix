import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "../../widgets"

// Clipboard history via cliphist. Click the icon to open the list; click an
// entry to copy it back (wl-copy). Clear wipes history.
Pill {
    id: root
    active: pop.open
    onClicked: pop.open = !pop.open

    Image { layer.enabled: true; layer.effect: Tint {}
        width: 16; height: 16
        sourceSize: Qt.size(32, 32)
        source: Quickshell.iconPath("edit-paste-symbolic", true)
    }

    property var items: []

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l).slice(0, 50).map(l => {
                    const tab = l.indexOf("\t")
                    return tab < 0 ? { id: l, preview: l } : { id: l.slice(0, tab), preview: l.slice(tab + 1) }
                })
            }
        }
    }
    Process { id: decode; property string clipId; command: ["bash", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", clipId] }
    Process { id: wipe; command: ["cliphist", "wipe"]; onExited: list.running = true }

    PopupCard {
        id: pop
        anchorItem: root
        barWindow: QsWindow.window
        name: "clipboard"
        cardWidth: 384
        spacing: 10
        onOpenChanged: if (open) list.running = true

        Row {
            width: parent.width
            Text { text: "Clipboard"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize; width: parent.width - clear.width }
            Text {
                id: clear
                text: "Clear"; color: Theme.muted; font.pixelSize: Theme.fontSize
                MouseArea { anchors.fill: parent; onClicked: wipe.running = true }
            }
        }
        Text { visible: root.items.length === 0; text: "Empty"; color: Theme.faint; font.pixelSize: Theme.fontSize }
        ListView {
            width: parent.width
            height: Math.min(contentHeight, 400)
            clip: true
            spacing: 6
            model: root.items
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 30
                radius: 6
                color: ma.containsMouse ? Theme.hover : Theme.card
                Text {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: modelData.preview
                    color: Theme.fg
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { decode.clipId = modelData.id; decode.running = true; pop.open = false }
                }
            }
        }
    }
}
