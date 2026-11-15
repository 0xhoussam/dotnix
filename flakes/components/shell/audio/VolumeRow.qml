import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../widgets"
import ".."

// Mute button + slider + percentage for one node (output, input or an
// application stream). `meter` draws a live level inside the slider track.
Item {
    id: root
    required property var node
    property string icon: ""       // optional fixed icon (else volume-based)
    property bool meter: false
    property bool compact: false
    implicitHeight: 30
    readonly property real v: AudioService.vol(node)
    readonly property bool m: AudioService.muted(node)

    PwNodePeakMonitor { id: peak; node: root.node; enabled: root.meter }

    Rectangle {
        id: mute
        width: 28; height: 28; radius: 14
        anchors.verticalCenter: parent.verticalCenter
        color: mm.containsMouse ? Theme.hover : "transparent"
        Image {
            layer.enabled: true; layer.effect: Tint {}
            anchors.centerIn: parent
            width: 16; height: 16; sourceSize: Qt.size(32, 32)
            opacity: root.m ? 0.5 : 1
            source: Quickshell.iconPath(root.icon || AudioService.volumeIcon(root.v, root.m), true)
        }
        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: AudioService.toggleMute(root.node) }
    }
    Slider {
        anchors { left: mute.right; leftMargin: 8; right: pct.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        to: AudioService.maxVolume
        marker: AudioService.allowBoost ? 1.0 : -1
        value: root.v
        level: root.meter ? peak.peak : -1
        opacity: root.m ? 0.5 : 1
        onMoved: v => AudioService.setVolume(root.node, v)
    }
    Text {
        id: pct
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 40
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.v * 100) + "%"
        color: root.m ? Theme.faint : Theme.fg
        font.pixelSize: 12
    }
}
