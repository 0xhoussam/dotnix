import QtQuick
import Quickshell.Io
import "."

// The password pill: a placeholder that doubles as the status, one dot per
// typed character, a submit button. The pill is narrow while empty and
// widens when you start typing. `status` / `error` feed the StateMessage.
Item {
    id: root
    property bool capsLock: false
    property string error: ""
    implicitWidth: 300
    implicitHeight: 52

    readonly property string status: error ? error
        : auth.message ? auth.message
        : capsLock ? "Caps lock is on" : ""

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

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: field.text.length > 0 || auth.busy ? root.width : root.width * 0.82
        height: root.height
        radius: height / 2
        color: Theme.card
        border.width: 1
        border.color: root.error ? Theme.error : Theme.overlay(0.08)
        Behavior on width { Anim { } }
        Behavior on border.color { CAnim { kind: "fastEffects" } }
        transform: Translate { id: shiftX }

        SequentialAnimation {
            id: shake
            Anim { target: shiftX; property: "x"; to: 12; duration: 70; kind: "standard" }
            Anim { target: shiftX; property: "x"; to: -12; duration: 90; kind: "standard" }
            Anim { target: shiftX; property: "x"; to: 8; duration: 80; kind: "standard" }
            Anim { target: shiftX; property: "x"; to: -4; duration: 80; kind: "standard" }
            Anim { target: shiftX; property: "x"; to: 0; duration: 100; kind: "fastSpatial" }
        }
        // sweeping highlight along the bottom while PAM works
        Item {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
            height: 2
            clip: true
            opacity: auth.busy ? 1 : 0
            Behavior on opacity { Anim { kind: "effects" } }
            Rectangle {
                width: 70; height: 2; radius: 1; color: Theme.cyan
                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: auth.busy
                    Anim { from: -70; to: pill.width; duration: 900; kind: "standard" }
                }
            }
        }

        // The real input stays (focus, paste, IME) but is invisible; the dots
        // below are what is drawn.
        TextInput {
            id: field
            anchors { left: parent.left; right: go.left; leftMargin: 22; rightMargin: 8; verticalCenter: parent.verticalCenter }
            echoMode: TextInput.Password
            passwordCharacter: "●"
            enabled: !auth.busy
            focus: true
            color: "transparent"
            selectionColor: "transparent"
            cursorDelegate: Item { }
            font { family: Theme.font; pixelSize: 9 }
            Component.onCompleted: forceActiveFocus()
            onActiveFocusChanged: if (!activeFocus && !auth.busy) forceActiveFocus()
            onTextChanged: root.error = ""
            onAccepted: auth.attempt(text)
            Keys.onEscapePressed: text = ""
        }
        FadeText {
            anchors { left: parent.left; right: go.left; leftMargin: 22; rightMargin: 8; verticalCenter: parent.verticalCenter }
            horizontalAlignment: Text.AlignHCenter
            text: auth.busy ? "AUTHENTICATING…" : "ENTER YOUR PASSWORD"
            color: auth.busy ? Theme.cyan : Theme.dim
            opacity: field.text.length > 0 && !auth.busy ? 0 : 1
            Behavior on color { CAnim { kind: "fastEffects" } }
            font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 * Theme.ls }
        }
        // each typed character pops in as a dot and shrinks away when deleted
        ListView {
            id: dots
            anchors { left: parent.left; right: go.left; leftMargin: 22; rightMargin: 8; verticalCenter: parent.verticalCenter }
            height: 18
            orientation: ListView.Horizontal
            spacing: 7
            interactive: false
            clip: true
            visible: !auth.busy
            model: field.text.length
            onCountChanged: positionViewAtEnd()
            delegate: Item {
                width: 9; height: dots.height
                Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 4.5; color: Theme.fg }
            }
            add: Transition {
                ParallelAnimation {
                    Anim { property: "scale"; from: 0; to: 1; kind: "fastSpatial" }
                    Anim { property: "opacity"; from: 0; to: 1; kind: "effects" }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    Anim { property: "scale"; to: 0.4; kind: "effects" }
                    Anim { property: "opacity"; to: 0; kind: "effects" }
                }
            }
            displaced: Transition { Anim { property: "x"; kind: "standard" } }
        }
        // blinking caret after the last dot
        Rectangle {
            visible: !auth.busy && field.text.length > 0
            x: dots.x + Math.min(dots.contentWidth + 3, dots.width - 1)
            Behavior on x { Anim { kind: "fastSpatial" } }
            anchors.verticalCenter: parent.verticalCenter
            width: 1.5; height: 16
            color: Theme.cyan
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: field.activeFocus
                PropertyAction { value: 1 }
                PauseAnimation { duration: 520 }
                PropertyAction { value: 0 }
                PauseAnimation { duration: 480 }
            }
        }

        // submit
        Rectangle {
            id: go
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: 36; height: 36
            radius: ma.containsMouse ? 12 : 18
            color: field.text.length > 0 && !auth.busy ? Theme.cyan : Theme.cardHigh
            scale: ma.pressed ? 0.9 : 1
            Behavior on radius { Anim { kind: "fastSpatial" } }
            Behavior on color { CAnim { kind: "fastEffects" } }
            Behavior on scale { Anim { kind: "fastSpatial" } }
            Text {
                anchors.centerIn: parent
                text: "→"
                color: field.text.length > 0 && !auth.busy ? Theme.bg : Theme.dim
                font { family: Theme.font; pixelSize: 17; bold: true }
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: !auth.busy; onClicked: auth.attempt(field.text) }
        }
    }
}
