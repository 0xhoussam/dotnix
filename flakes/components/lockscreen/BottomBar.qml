import QtQuick
import Quickshell
import Quickshell.Io
import "."

// "• HYPRLAND ............ RESTART  SHUT DOWN" over a hairline.
Column {
    readonly property string session: (Quickshell.env("XDG_CURRENT_DESKTOP") || "Wayland").split(":")[0]

    // Power action that needs a second click within a few seconds.
    component PowerButton: Text {
        id: btn
        property string label
        property var command
        property bool armed: false
        text: armed ? "CONFIRM " + label + "?" : label
        color: armed ? Theme.error : (ma.containsMouse ? Theme.cyan : Theme.fg)
        font { family: Theme.font; pixelSize: 11; weight: Font.Bold; letterSpacing: 2 }
        Process { id: proc; command: btn.command }
        Timer { id: disarm; interval: 4000; onTriggered: btn.armed = false }
        MouseArea {
            id: ma
            anchors { fill: parent; margins: -4 }
            hoverEnabled: true
            onClicked: {
                if (!btn.armed) { btn.armed = true; disarm.restart(); return }
                btn.armed = false
                proc.running = true
            }
        }
    }

    spacing: 8
    Row {
        width: parent.width
        spacing: 24
        Row {
            id: left
            spacing: 10
            width: parent.width - restart.width - shutdown.width - 48
            Rectangle { width: 5; height: 5; radius: 3; color: Theme.cyan; anchors.verticalCenter: parent.verticalCenter }
            Text { text: session.toUpperCase(); color: Theme.fg; font { family: Theme.font; pixelSize: 11; weight: Font.Bold; letterSpacing: 2 } }
        }
        PowerButton { id: restart; label: "RESTART"; command: ["systemctl", "reboot"] }
        PowerButton { id: shutdown; label: "SHUT DOWN"; command: ["systemctl", "poweroff"] }
    }
    Rectangle { width: parent.width; height: 1; color: Theme.line }
}
