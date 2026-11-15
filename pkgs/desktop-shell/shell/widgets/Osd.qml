import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../audio"
import ".."

// Small overlay for transient feedback: output volume / mute, microphone
// mute, keyboard layout (all automatic) and brightness (triggered over IPC
// by the brightness keybinds: `shell-ctl osd brightness`, so hypridle's
// dimming does not pop it up). Click-through. Quiet while the volume panel
// is open and for volume changes caused by switching devices.
Scope {
    id: root
    property bool armed: false
    property bool shown: false
    // what is shown now
    property string icon: ""
    property real value: 0      // 0..1, <0 = no bar
    property string label: ""
    property bool boosted: false

    function show(icon, value, label, boosted) {
        root.icon = icon; root.value = value; root.label = label; root.boosted = !!boosted
        shown = true
        hide.restart()
    }
    Timer { id: hide; interval: 1200; onTriggered: root.shown = false }
    // ignore the initial values and device switches
    Timer { id: arm; interval: 1500; running: true; onTriggered: root.armed = true }

    // ---- volume / mute (default output) ----
    readonly property var sink: AudioService.sink
    readonly property real v: AudioService.vol(sink)
    readonly property bool m: AudioService.muted(sink)
    onSinkChanged: { armed = false; arm.restart() }
    function volumeOsd() {
        if (!armed || UiState.volumePanelOpen) return
        show(AudioService.volumeIcon(v, m), m ? 0 : Math.min(1, v / AudioService.maxVolume), m ? "Muted" : Math.round(v * 100) + "%", v > 1.0001)
    }
    onVChanged: volumeOsd()
    onMChanged: volumeOsd()

    // ---- microphone mute ----
    readonly property bool micMuted: AudioService.muted(AudioService.source)
    onMicMutedChanged: if (armed) show(micMuted ? "microphone-sensitivity-muted-symbolic" : "audio-input-microphone-symbolic", -1, micMuted ? "Microphone muted" : "Microphone on")

    // ---- keyboard layout ----
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout" || !root.armed) return
            const i = event.data.indexOf(",")
            root.show("input-keyboard-symbolic", -1, event.data.slice(i + 1))
        }
    }

    // ---- brightness (IPC) ----
    Process {
        id: bright
        command: ["brightnessctl", "-m"]
        // "device,class,current,percent%,max"
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",")
                const pct = parseInt(f[3])
                if (!isNaN(pct)) root.show("display-brightness-symbolic", pct / 100, pct + "%")
            }
        }
    }
    function brightness() { bright.running = true }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: root.shown || card.opacity > 0.01
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "shell-osd"
        anchors.bottom: true
        margins.bottom: 90
        implicitWidth: 300
        implicitHeight: 56
        mask: Region {}

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 28
            color: Theme.osdBg
            border.color: Theme.border
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Row {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                spacing: 12
                Image {
                    layer.enabled: true; layer.effect: Tint {}
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; sourceSize: Qt.size(40, 40)
                    source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
                }
                Rectangle {
                    visible: root.value >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20 - 12 - 12 - 90; height: 6; radius: 3
                    color: Theme.track
                    Rectangle {
                        height: parent.height; radius: 3
                        width: parent.width * Math.max(0, Math.min(1, root.value))
                        color: root.boosted ? Theme.warn : Theme.accent
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.value >= 0 ? 90 : parent.width - 20 - 12
                    horizontalAlignment: root.value >= 0 ? Text.AlignRight : Text.AlignLeft
                    elide: Text.ElideRight
                    text: root.label
                    color: Theme.fg; font.pixelSize: 12
                }
            }
        }
    }
}
