import QtQuick
import ".."

// Horizontal slider: drag, click to jump, scroll. Writes are throttled to
// about 30 per second (a final one on release) so PipeWire is not flooded.
Item {
    id: root
    property real value: 0 // 0..to
    property real from: 0
    property real to: 1
    property real step: 0.05 // scroll step
    property real marker: -1 // optional tick (the 100% point when boost is allowed)
    property real level: -1 // optional level meter 0..1, drawn inside the track
    signal moved(real value)

    implicitHeight: 22
    implicitWidth: 160
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    function emitMoved(v) { root.moved(Math.max(from, Math.min(to, v))) }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6; radius: 3
        color: Qt.rgba(1, 1, 1, 0.14)
        // level meter behind the fill
        Rectangle {
            visible: root.level >= 0
            height: parent.height; radius: 3
            width: parent.width * Math.max(0, Math.min(1, root.level))
            color: Qt.rgba(1, 1, 1, 0.22)
            Behavior on width { NumberAnimation { duration: 80 } }
        }
        Rectangle {
            height: parent.height; radius: 3
            width: parent.width * root.frac
            color: root.value > 1.0001 ? "#f5a524" : Theme.accent
        }
        Rectangle {
            visible: root.marker > root.from && root.marker < root.to
            x: parent.width * (root.marker - root.from) / (root.to - root.from) - 1
            y: -2; width: 2; height: parent.height + 4
            color: Qt.rgba(1, 1, 1, 0.5)
        }
    }
    Rectangle {
        x: track.width * root.frac - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 7
        color: "white"
        scale: area.pressed ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }

    property real pending: -1
    Timer {
        id: throttle
        interval: 33
        onTriggered: if (root.pending >= 0) { root.emitMoved(root.pending); root.pending = -1 }
    }
    function fromX(x) { return from + (to - from) * Math.max(0, Math.min(1, x / track.width)) }
    function drag(x) {
        const v = fromX(x)
        if (!throttle.running) { emitMoved(v); throttle.start() } else pending = v
    }

    MouseArea {
        id: area
        anchors { fill: parent; topMargin: -4; bottomMargin: -4 }
        hoverEnabled: true
        onPressed: mouse => root.drag(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.drag(mouse.x) }
        onReleased: mouse => { throttle.stop(); root.pending = -1; root.emitMoved(root.fromX(mouse.x)) }
        onWheel: wheel => root.emitMoved(root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step))
    }
}
