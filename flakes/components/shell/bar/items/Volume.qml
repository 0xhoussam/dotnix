import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../.."
import "../../widgets"

// Default-speaker volume. Click toggles mute, scroll adjusts level.
Pill {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    visible: sink !== null
    PwObjectTracker { objects: [root.sink] }

    onClicked: if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    onScrolled: wheel => {
        if (!sink || !sink.audio) return
        const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + step))
        sink.audio.muted = false
    }

    Row {
        spacing: 5
        Image { layer.enabled: true; layer.effect: Tint {}
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: Quickshell.iconPath(root.muted || root.vol === 0 ? "audio-volume-muted-symbolic"
                : root.vol < 0.34 ? "audio-volume-low-symbolic"
                : root.vol < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic", true)
        }
        Text {
            text: Math.round(root.vol * 100) + "%"
            color: Qt.rgba(1, 1, 1, 0.88)
            font.pixelSize: Theme.fontSize
        }
    }
}
