import QtQuick
import Quickshell.Io

// CPU / memory / disk gauges. Hover the card to swap them for the session
// buttons; restart and shut down need a second click.
Card {
    id: root
    implicitHeight: 148
    clip: true
    readonly property bool controls: hover.hovered

    HoverHandler { id: hover }

    // ---- gauges
    Row {
        id: gauges
        anchors.centerIn: parent
        spacing: 22
        opacity: root.controls ? 0 : 1
        Behavior on opacity { Anim { kind: "effects" } }
        transform: Translate { y: root.controls ? 30 : 0; Behavior on y { Anim { kind: "emphasized" } } }
        Gauge {
            value: Sys.cpu; text: Math.round(Sys.cpu * 100) + "%"
            caption: Sys.temp >= 0 ? "CPU " + Sys.temp + "°" : "CPU"
            tint: Sys.temp > 90 ? Theme.error : Theme.cyan
        }
        Gauge { value: Sys.mem; text: Math.round(Sys.mem * 100) + "%"; caption: "MEM"; tint: Theme.cyan }
        Gauge { value: Sys.disk; text: Math.round(Sys.disk * 100) + "%"; caption: "DISK"; tint: Theme.cyan }
    }

    // ---- session buttons
    component Action: Rectangle {
        id: a
        property string label
        property var command
        property bool confirmFirst: true
        property bool armed: false
        implicitWidth: 78; implicitHeight: 78
        radius: ma.containsMouse ? 20 : 30
        color: armed ? Theme.error : (ma.containsMouse ? Theme.cardHigh : Theme.card)
        scale: ma.pressed ? 0.94 : 1
        Behavior on radius { Anim { kind: "fastSpatial" } }
        Behavior on color { CAnim { kind: "fastEffects" } }
        Behavior on scale { Anim { kind: "fastSpatial" } }
        Process { id: proc; command: a.command }
        Timer { id: disarm; interval: 4000; onTriggered: a.armed = false }
        Text {
            anchors { fill: parent; margins: 6 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            text: a.armed ? "CONFIRM?" : a.label
            color: a.armed ? Theme.bg : Theme.fg
            font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.5 * Theme.ls }
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            onClicked: {
                if (a.confirmFirst && !a.armed) { a.armed = true; disarm.restart(); return }
                a.armed = false
                proc.running = true
            }
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: 12
        opacity: root.controls ? 1 : 0
        enabled: root.controls
        Behavior on opacity { Anim { kind: "effects" } }
        transform: Translate { y: root.controls ? 0 : -30; Behavior on y { Anim { kind: "emphasized" } } }
        Action { label: "SUSPEND"; command: ["systemctl", "suspend"]; confirmFirst: false }
        Action { label: "RESTART"; command: ["systemctl", "reboot"] }
        Action { label: "SHUT DOWN"; command: ["systemctl", "poweroff"] }
    }
}
