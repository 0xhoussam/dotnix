import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Services.Mpris

// Now playing, with the cover art blurred behind the controls.
Card {
    id: root
    clip: true
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) || players[0] || null
    readonly property string art: player ? (player.trackArtUrl || "") : ""

    Image {
        id: cover
        anchors.fill: parent
        source: root.art
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { Anim { kind: "slowEffects"; duration: 600 } }
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true; blur: 0.6; blurMax: 32; autoPaddingEnabled: false
            maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1
        }
        Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.62 }
    }

    Item {
        id: coverMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
    }

    // round control button; `glyph` is drawn, so no icon theme is needed
    component Btn: Rectangle {
        id: b
        property string glyph: "play"    // play | pause | prev | next
        property bool primary: false
        property bool on: true
        signal clicked()
        implicitWidth: primary ? 56 : 42
        implicitHeight: 42
        radius: ma.containsMouse ? 14 : height / 2
        color: primary ? Theme.cyan : (ma.containsMouse ? Theme.cardHigh : Theme.card)
        opacity: on ? 1 : 0.35
        scale: ma.pressed ? 0.92 : 1
        Behavior on radius { Anim { kind: "fastSpatial" } }
        Behavior on color { CAnim { kind: "fastEffects" } }
        Behavior on scale { Anim { kind: "fastSpatial" } }
        readonly property color ink: primary ? Theme.bg : Theme.fg
        Shape {
            anchors.centerIn: parent
            width: 16; height: 16
            visible: b.glyph !== "pause"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: b.ink; strokeColor: "transparent"
                PathPolyline {
                    path: b.glyph === "prev" ? [Qt.point(14, 1), Qt.point(14, 15), Qt.point(4, 8)]
                        : b.glyph === "next" ? [Qt.point(2, 1), Qt.point(2, 15), Qt.point(12, 8)]
                        : [Qt.point(3, 0), Qt.point(3, 16), Qt.point(15, 8)]
                }
            }
        }
        Rectangle {
            visible: b.glyph === "prev" || b.glyph === "next"
            x: parent.width / 2 + (b.glyph === "prev" ? -8 : 6)
            anchors.verticalCenter: parent.verticalCenter
            width: 2; height: 14; color: b.ink
        }
        Row {
            anchors.centerIn: parent
            spacing: 4
            visible: b.glyph === "pause"
            Rectangle { width: 5; height: 16; radius: 1.5; color: b.ink }
            Rectangle { width: 5; height: 16; radius: 1.5; color: b.ink }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: b.on; onClicked: b.clicked() }
    }

    Column {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 18 }
        spacing: 4
        FadeText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.player ? (root.player.trackTitle || "Unknown track") : "Nothing playing"
            color: Theme.cyan
            font { family: Theme.font; pixelSize: 15; weight: Font.Black }
        }
        FadeText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.player ? (root.player.trackArtist || "Unknown artist") : "Try playing some music"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
        Item { width: 1; height: 8 }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Btn { glyph: "prev"; on: root.player !== null && root.player.canGoPrevious; onClicked: root.player.previous() }
            Btn {
                primary: true
                glyph: root.player && root.player.isPlaying ? "pause" : "play"
                on: root.player !== null && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
            Btn { glyph: "next"; on: root.player !== null && root.player.canGoNext; onClicked: root.player.next() }
        }
    }
}
