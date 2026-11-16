import QtQuick
import QtQuick.Shapes
import ".."
import "../motion"

// A panel that grows out of the bar's bottom edge: same colour as the bar,
// square top corners, rounded bottom corners, and concave flares where it
// meets the bar so the two read as one shape. Place it so its top edge is
// the bar's bottom edge. Children go inside the card (clipped while it
// opens, and laid out at their final size, so the card reveals them like a
// shutter). Set `cardWidth` and `contentHeight` to the content's size.
Item {
    id: root
    property bool open: false
    property real cardWidth: 300
    property real contentHeight: 100
    readonly property int flare: 16
    readonly property int cornerRadius: 16
    // false once the close animation has finished: unmap the window then
    readonly property bool shown: open || card.height > 0.5
    default property alias content: inner.data

    implicitWidth: cardWidth + 2 * flare
    implicitHeight: contentHeight
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: card
        x: root.flare
        width: root.cardWidth
        height: root.open ? root.contentHeight : 0
        color: Theme.barBg
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.cornerRadius
        bottomRightRadius: root.cornerRadius
        clip: true
        Behavior on height { Anim { kind: "emphasized" } }

        Item {
            id: inner
            width: parent.width
            height: root.contentHeight
            opacity: root.open ? 1 : 0
            Behavior on opacity { Anim { kind: "effects" } }
        }
    }

    // Concave flares: the corner square minus a quarter circle.
    component Flare: Shape {
        id: fl
        property bool isLeft: true
        width: root.flare
        height: root.flare
        preferredRendererType: Shape.CurveRenderer
        opacity: Math.min(1, card.height / root.flare)
        ShapePath {
            fillColor: Theme.barBg
            strokeColor: "transparent"
            startX: fl.isLeft ? 0 : fl.width
            startY: 0
            PathLine { x: fl.isLeft ? fl.width : 0; y: 0 }
            PathLine { x: fl.isLeft ? fl.width : 0; y: fl.height }
            PathArc {
                x: fl.isLeft ? 0 : fl.width
                y: 0
                radiusX: root.flare
                radiusY: root.flare
                direction: fl.isLeft ? PathArc.Counterclockwise : PathArc.Clockwise
            }
        }
    }
    Flare { isLeft: true; x: 0 }
    Flare { isLeft: false; x: root.flare + root.cardWidth }
}
