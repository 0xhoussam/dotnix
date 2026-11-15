import QtQuick
import "../widgets"
import ".."

// One application stream: icon, name (and media title), slider, mute.
Column {
    id: root
    required property var node
    spacing: 2
    Row {
        spacing: 8
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; sourceSize: Qt.size(36, 36)
            source: AudioService.appIcon(root.node)
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: AudioService.appName(root.node); color: Theme.fg; font { pixelSize: 12; bold: true } elide: Text.ElideRight; width: root.width - 30 }
            Text { visible: text !== ""; text: AudioService.appDetail(root.node); color: Theme.muted; font.pixelSize: 11; elide: Text.ElideRight; width: root.width - 30 }
        }
    }
    VolumeRow { width: parent.width; node: root.node }
}
