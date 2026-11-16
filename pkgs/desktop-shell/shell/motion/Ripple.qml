import QtQuick
import QtQuick.Effects
import ".."

// Material press ripple, clipped to the parent's rounded rect. Drop it into a
// Rectangle, set `radius`, and forward the MouseArea:
//   onPressed: ripple.press(mouse.x, mouse.y)   and   ripple.pressed = pressed
Item {
    id: root
    property real radius: 0
    property color color: Theme.fg
    property bool pressed: false
    property real pressX: width / 2
    property real pressY: height / 2
    readonly property real endRadius: Math.hypot(Math.max(pressX, width - pressX), Math.max(pressY, height - pressY)) * 1.1

    function press(x, y) {
        pressX = x
        pressY = y
        fade.stop()
        grow.stop()
        circle.r = 0
        circle.opacity = 0.12
        grow.to = endRadius
        grow.start()
    }
    function maybeFade() {
        if (!pressed && !grow.running && circle.opacity > 0) fade.start()
    }
    onPressedChanged: maybeFade()

    anchors.fill: parent
    layer.enabled: circle.opacity > 0
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.layer.enabled
        Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
    }
    Rectangle {
        id: circle
        property real r: 0
        x: root.pressX - r
        y: root.pressY - r
        width: r * 2
        height: r * 2
        radius: r
        color: root.color
        opacity: 0
    }
    Anim { id: grow; target: circle; property: "r"; kind: "emphasized"; onRunningChanged: root.maybeFade() }
    Anim { id: fade; target: circle; property: "opacity"; to: 0; kind: "effects" }
}
