import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.."
import "../../widgets"
import "../../audio"

// Output volume pill + sound panel. Left click opens the panel, middle
// click mutes the microphone, scroll changes the volume.
Pill {
    id: root
    readonly property var sink: AudioService.sink
    readonly property real vol: AudioService.vol(sink)
    readonly property bool muted: AudioService.muted(sink)
    visible: sink !== null && sink !== undefined
    active: pop.open

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) AudioService.toggleMute(AudioService.source)
        else pop.open = !pop.open
    }
    onScrolled: wheel => AudioService.nudge(sink, wheel.angleDelta.y > 0 ? 0.05 : -0.05)

    Row {
        spacing: 5
        Item {
            width: 16; height: 16
            anchors.verticalCenter: parent.verticalCenter
            Image { layer.enabled: true; layer.effect: Tint {}
                anchors.fill: parent
                sourceSize: Qt.size(32, 32)
                source: Quickshell.iconPath(AudioService.volumeIcon(root.vol, root.muted), true)
            }
            // microphone in use
            Rectangle {
                visible: AudioService.micInUse
                width: 7; height: 7; radius: 4
                anchors { right: parent.right; top: parent.top; rightMargin: -3; topMargin: -2 }
                color: AudioService.muted(AudioService.source) ? "#8d8d8d" : "#ff5f57"
                border.color: Theme.barBg; border.width: 1
            }
        }
        Text {
            text: Math.round(root.vol * 100) + "%"
            color: Theme.textBar
            font.pixelSize: Theme.fontSize
        }
    }


    PopupCard {
        id: pop
        anchorItem: root
        cardWidth: 372
        spacing: 10
        onOpenChanged: UiState.volumePanelOpen = open


        Item {
            width: parent.width; height: 28
            Text { text: "Sound"; color: Theme.fg; font { pixelSize: 16; bold: true } anchors.verticalCenter: parent.verticalCenter }
            Chip {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                label: "Sound Settings…"
                onClicked: { pop.open = false; Quickshell.execDetached(["pavucontrol"]) }
            }
        }

        // ---- output
        Text { text: "Output"; color: Theme.muted; font { pixelSize: 12; bold: true } }
        VolumeRow { width: parent.width; node: AudioService.sink; meter: pop.open }
        DeviceList {
            width: parent.width
            devices: AudioService.sinks
            current: AudioService.sink
            onPicked: n => AudioService.setDefaultSink(n)
        }

        // ---- input
        Text { text: "Input"; color: Theme.muted; font { pixelSize: 12; bold: true } topPadding: 4 }
        VolumeRow { width: parent.width; node: AudioService.source; icon: AudioService.muted(AudioService.source) ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic"; meter: pop.open }
        DeviceList {
            width: parent.width
            devices: AudioService.sources
            current: AudioService.source
            onPicked: n => AudioService.setDefaultSource(n)
        }

        // ---- applications
        Column {
            visible: AudioService.playStreams.length > 0
            width: parent.width
            spacing: 8
            Text { text: "Applications"; color: Theme.muted; font { pixelSize: 12; bold: true } topPadding: 4 }
            Repeater {
                model: AudioService.playStreams
                AppRow { required property var modelData; node: modelData; width: pop.contentWidth }
            }
        }
        Column {
            visible: AudioService.recStreams.length > 0
            width: parent.width
            spacing: 8
            Text { text: "Recording"; color: Theme.muted; font { pixelSize: 12; bold: true } topPadding: 4 }
            Repeater {
                model: AudioService.recStreams
                AppRow { required property var modelData; node: modelData; width: pop.contentWidth }
            }
        }

        // ---- options
        Rectangle {
            width: parent.width; height: 36; radius: 12
            color: Theme.surface
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Allow volume above 100%"; color: Theme.fg; font.pixelSize: Theme.fontSize }
            Toggle { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } checked: AudioService.allowBoost; onToggled: v => AudioService.setAllowBoost(v) }
        }
    }
}
