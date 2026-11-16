import QtQuick
import QtQuick.Effects
import "."

// One surface per monitor: blurred wallpaper behind a panel that starts as a
// padlock. On lock the padlock card pops in and spins, then grows into the
// full panel (weather / fetch / media, clock + password, resources /
// notifications) while the padlock fades out. Unlock plays it backwards.
Item {
    id: root

    // The panel is laid out at 1040x640 and scaled to the screen height.
    readonly property real s: Math.max(0.7, Math.min(1.3, height / 1080))
    readonly property real fullW: content.logicalWidth * s
    readonly property real fullH: content.logicalHeight * s
    readonly property real smallSize: 150
    readonly property real smallRadius: 40
    readonly property real fullRadius: 34

    // animated state
    property real bgShown: 0
    property real cw: smallSize
    property real ch: smallSize
    property real cr: smallRadius
    property real glyphOpacity: 1
    property real glyphRot: 180
    property real contentOpacity: 0
    property real contentK: 0.92
    property real cardOpacity: 1
    property bool started: false

    function start() {
        if (started || height <= 0) return
        started = true
        initAnim.start()
    }
    onHeightChanged: start()
    Component.onCompleted: start()
    Connections {
        target: Session
        function onLeavingChanged() {
            if (!Session.leaving) return
            initAnim.stop()
            unlockAnim.start()
        }
    }

    // any input resumes an idle-paused video
    HoverHandler { onPointChanged: Session.noteInput() }
    Keys.onPressed: event => { Session.noteInput(); event.accepted = false }

    Rectangle { anchors.fill: parent; color: Theme.bg }
    Item {
        anchors.fill: parent
        opacity: root.bgShown
        layer.enabled: true
        layer.effect: MultiEffect { autoPaddingEnabled: false; blurEnabled: true; blurMax: 48; blur: 0.55 }
        Background { anchors.fill: parent }
    }
    Rectangle {
        anchors.fill: parent
        opacity: root.bgShown
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    Item {
        id: lockContent
        anchors.centerIn: parent
        width: root.cw
        height: root.ch
        rotation: 180
        scale: 0
        opacity: root.cardOpacity
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: root.cr
            color: Theme.panel
            border.width: 1
            border.color: Theme.panelLine
        }
        LockGlyph {
            anchors.centerIn: parent
            rotation: root.glyphRot
            opacity: root.glyphOpacity
        }
        Item {
            anchors.centerIn: parent
            width: content.width
            height: content.height
            scale: root.s * root.contentK
            opacity: root.contentOpacity
            Content { id: content }
        }
    }

    SequentialAnimation {
        id: initAnim
        ParallelAnimation {
            Anim { target: root; property: "bgShown"; to: 1; duration: 700; kind: "standard" }
            SequentialAnimation {
                ParallelAnimation {
                    Anim { target: lockContent; property: "scale"; to: 1; kind: "fastSpatial" }
                    Anim { target: lockContent; property: "rotation"; to: 360; duration: 350; kind: "standard" }
                }
                PauseAnimation { duration: 120 }
                ParallelAnimation {
                    Anim { target: root; property: "glyphRot"; to: 360; kind: "standard" }
                    Anim { target: root; property: "glyphOpacity"; to: 0; kind: "effects" }
                    Anim { target: root; property: "contentOpacity"; to: 1; kind: "effects"; duration: 350 }
                    Anim { target: root; property: "contentK"; to: 1; kind: "emphasized"; duration: 600 }
                    Anim { target: root; property: "cr"; to: root.fullRadius; kind: "emphasized"; duration: 600 }
                    Anim { target: root; property: "cw"; to: root.fullW; kind: "emphasized"; duration: 600 }
                    Anim { target: root; property: "ch"; to: root.fullH; kind: "emphasized"; duration: 600 }
                }
            }
        }
    }

    SequentialAnimation {
        id: unlockAnim
        ParallelAnimation {
            Anim { target: root; property: "contentOpacity"; to: 0; kind: "fastEffects" }
            Anim { target: root; property: "contentK"; to: 0.92; kind: "emphasized"; duration: 500 }
            Anim { target: root; property: "cw"; to: root.smallSize; kind: "emphasized"; duration: 500 }
            Anim { target: root; property: "ch"; to: root.smallSize; kind: "emphasized"; duration: 500 }
            Anim { target: root; property: "cr"; to: root.smallRadius; kind: "emphasized"; duration: 500 }
            SequentialAnimation {
                PauseAnimation { duration: 150 }
                Anim { target: root; property: "glyphOpacity"; to: 1; kind: "effects"; duration: 300 }
            }
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                Anim { target: root; property: "bgShown"; to: 0; duration: 500; kind: "standard" }
            }
        }
        ParallelAnimation {
            Anim { target: lockContent; property: "scale"; to: 0; kind: "fastEffects"; duration: 200 }
            Anim { target: root; property: "cardOpacity"; to: 0; kind: "fastEffects"; duration: 200 }
        }
    }
}
