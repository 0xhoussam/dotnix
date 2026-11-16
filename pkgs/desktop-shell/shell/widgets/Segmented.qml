import QtQuick
import ".."
import "../motion"

// Option picker laid out as a grid of cells with a sliding highlight.
// options: [{ label: "Balanced", value: "balanced" }, ...]; `current` is a value.
Item {
    id: root
    property var options: []
    property var current
    property int columns: 2
    property int gap: 6
    property int cellHeight: 32
    signal picked(var value)

    readonly property int idx: options.findIndex(o => o.value === current)
    readonly property int cols: Math.max(1, Math.min(columns, options.length))
    readonly property int rows: Math.ceil(options.length / cols)
    readonly property real cellW: (width - (cols - 1) * gap) / cols
    function cellX(i) { return (i % cols) * (cellW + gap) }
    function cellY(i) { return Math.floor(i / cols) * (cellHeight + gap) }

    implicitHeight: rows > 0 ? rows * cellHeight + (rows - 1) * gap : 0

    Repeater {
        model: root.options
        Rectangle {
            required property var modelData
            required property int index
            x: root.cellX(index); y: root.cellY(index)
            width: root.cellW; height: root.cellHeight
            radius: 10
            color: ma.containsMouse ? Theme.surfaceHover : Theme.surface
            Behavior on color { CAnim { kind: "fastEffects" } }
            Ripple { id: rp; radius: parent.radius }
            Text {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                text: parent.modelData.label
                color: root.idx === parent.index ? Theme.fg : Theme.muted
                font { pixelSize: 12; bold: true }
                Behavior on color { CAnim { kind: "fastEffects" } }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                onPressed: mouse => rp.press(mouse.x, mouse.y)
                onPressedChanged: rp.pressed = pressed
                onClicked: root.picked(parent.modelData.value)
            }
        }
    }
    // selection outline, slides between cells
    Rectangle {
        visible: root.idx >= 0
        x: root.idx >= 0 ? root.cellX(root.idx) : 0
        y: root.idx >= 0 ? root.cellY(root.idx) : 0
        width: root.cellW; height: root.cellHeight
        radius: 10
        color: Theme.accentSoft
        border.width: 1
        border.color: Theme.accent
        Behavior on x { Anim { } }
        Behavior on y { Anim { } }
        // clicks fall through to the cells underneath
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton }
    }
}
