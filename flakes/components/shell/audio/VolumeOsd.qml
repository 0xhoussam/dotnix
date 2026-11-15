import QtQuick
import Quickshell
import Quickshell.Wayland
import "../widgets"
import ".."

// Small overlay shown for about a second after the output volume or mute
// changes (keybind, scroll, panel). Click-through. Not shown while the
// volume panel is open, nor for changes caused by switching devices.
Scope {
    id: root
    readonly property bool panelOpen: UiState.volumePanelOpen
    property bool armed: false
    readonly property var sink: AudioService.sink
    readonly property real v: AudioService.vol(sink)
    readonly property bool m: AudioService.muted(sink)

    // ignore the initial values and device switches
    Timer { id: arm; interval: 1500; running: true; onTriggered: root.armed = true }
    onSinkChanged: { armed = false; arm.restart() }
    function ping() { if (armed && !panelOpen) { shown = true; hide.restart() } }
    onVChanged: ping()
    onMChanged: ping()

    property bool shown: false
    Timer { id: hide; interval: 1200; onTriggered: root.shown = false }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: root.shown || card.opacity > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "volume-osd"
        anchors.bottom: true
        margins.bottom: 90
        implicitWidth: 260
        implicitHeight: 56
        mask: Region {}

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 28
            color: Qt.rgba(0.14, 0.14, 0.14, 0.94)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Row {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                spacing: 12
                Image {
                    layer.enabled: true; layer.effect: Tint {}
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; sourceSize: Qt.size(40, 40)
                    source: Quickshell.iconPath(AudioService.volumeIcon(root.v, root.m), true)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20 - 12 - 12 - 40; height: 6; radius: 3
                    color: Qt.rgba(1, 1, 1, 0.14)
                    Rectangle {
                        height: parent.height; radius: 3
                        width: parent.width * Math.min(1, root.m ? 0 : root.v / AudioService.maxVolume)
                        color: root.v > 1.0001 ? "#f5a524" : Theme.accent
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; horizontalAlignment: Text.AlignRight
                    text: root.m ? "Muted" : Math.round(root.v * 100) + "%"
                    color: Theme.fg; font.pixelSize: 12
                }
            }
        }
    }
}
