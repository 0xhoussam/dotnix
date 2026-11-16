import QtQuick
import QtQuick.Shapes

// Circular gauge: a ring that fills to `value` (0..1), a number inside, a
// caption below. The fill eases to new values.
Item {
    id: root
    property real value: 0
    property string text: ""
    property string caption: ""
    property color tint: Theme.cyan
    property int size: 76
    property real shown: value
    Behavior on shown { Anim { kind: "standard"; duration: 700 } }

    implicitWidth: size
    implicitHeight: size + 22

    Shape {
        width: root.size; height: root.size
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.overlay(0.12)
            strokeWidth: 7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size / 2 - 5; radiusY: root.size / 2 - 5; startAngle: -90; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.tint
            strokeWidth: 7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.size / 2; centerY: root.size / 2; radiusX: root.size / 2 - 5; radiusY: root.size / 2 - 5; startAngle: -90; sweepAngle: Math.max(0.5, 360 * root.shown) }
        }
    }
    FadeText {
        x: 0; y: 0; width: root.size; height: root.size
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.text
        color: Theme.fg
        font { family: Theme.font; pixelSize: 17; weight: Font.Black }
    }
    Text {
        y: root.size + 4; width: root.size
        horizontalAlignment: Text.AlignHCenter
        text: root.caption
        color: Theme.dim
        font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 * Theme.ls }
    }
}
