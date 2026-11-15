import QtQuick
import Quickshell
import Quickshell.Io
import "."

// Bare password field: user name, dots over a thin underline, arrow to
// submit, one status line (authenticating / error / caps lock).
Column {
    id: root
    property bool capsLock: false
    property string error: ""
    spacing: 8
    width: 210

    Auth {
        id: auth
        onSuccess: Session.unlock()
        onFailed: msg => {
            root.error = msg
            field.text = ""
            field.forceActiveFocus()
            shake.restart()
        }
    }

    // Caps lock via the LED (Qt has no direct API).
    Process {
        id: caps
        command: ["bash", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | grep -q 1 && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.capsLock = text.trim() === "1" }
    }
    Timer { interval: 400; running: true; repeat: true; onTriggered: caps.running = true }

    readonly property string status: auth.busy ? "AUTHENTICATING…"
        : error ? error.toUpperCase()
        : auth.message ? auth.message.toUpperCase()
        : capsLock ? "CAPS LOCK IS ON" : ""

    Text {
        anchors.right: parent.right
        text: Session.user.toUpperCase()
        color: Theme.fg
        font { family: Theme.font; pixelSize: 15; weight: Font.Black; letterSpacing: 2 * Theme.ls }
    }

    Item {
        id: fieldBox
        width: parent.width
        height: 28
        SequentialAnimation {
            id: shake
            NumberAnimation { target: fieldBox; property: "x"; to: 10; duration: 76 }
            NumberAnimation { target: fieldBox; property: "x"; to: -10; duration: 76 }
            NumberAnimation { target: fieldBox; property: "x"; to: 7; duration: 76 }
            NumberAnimation { target: fieldBox; property: "x"; to: -4; duration: 76 }
            NumberAnimation { target: fieldBox; property: "x"; to: 0; duration: 76 }
        }
        TextInput {
            id: field
            anchors { left: parent.left; right: go.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            echoMode: TextInput.Password
            passwordCharacter: "●"
            enabled: !auth.busy
            focus: true
            color: Theme.fg
            cursorDelegate: Rectangle { width: 1; color: Theme.cyan }
            font { family: Theme.font; pixelSize: 9; letterSpacing: 8 * Theme.ls }
            Component.onCompleted: forceActiveFocus()
            onTextChanged: root.error = ""
            onAccepted: auth.attempt(text)
            // Escape clears the field.
            Keys.onEscapePressed: text = ""
            Text {
                visible: !field.text
                text: "PASSWORD"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10; letterSpacing: 3 * Theme.ls }
            }
        }
        Text {
            id: go
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "→"
            color: Theme.cyan
            font { pixelSize: 16; bold: true }
            MouseArea { anchors.fill: parent; enabled: !auth.busy; onClicked: auth.attempt(field.text) }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.fieldLine }
    }

    Text {
        anchors.right: parent.right
        text: root.status
        opacity: root.status ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        color: root.error ? Theme.error : Theme.dim
        font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 * Theme.ls }
    }
}
