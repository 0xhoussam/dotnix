import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import ".."

// Four concave corners framing the monitor, matching the bar's rounding.
// Click-through (empty input mask) so events reach windows below.
Scope {
    id: root
    required property var screen
    readonly property int r: Config.screenCornerRadius

    Variants {
        model: root.r > 0 ? ["tl", "tr", "bl", "br"] : []
        PanelWindow {
            id: win
            required property string modelData
            screen: root.screen
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "screencorner"
            mask: Region {}
            implicitWidth: root.r
            implicitHeight: root.r
            anchors {
                top: modelData[0] === "t"
                bottom: modelData[0] === "b"
                left: modelData[1] === "l"
                right: modelData[1] === "r"
            }

            // Solid wedge in the outer corner, quarter circle carved inward.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: Theme.barBg
                    strokeColor: "transparent"
                    startX: win.modelData === "tl" || win.modelData === "bl" ? 0 : root.r
                    startY: win.modelData[0] === "t" ? 0 : root.r
                    // Outer corner -> along one edge -> arc -> back.
                    PathLine {
                        x: win.modelData[1] === "l" ? root.r : 0
                        y: win.modelData[0] === "t" ? 0 : root.r
                    }
                    PathArc {
                        x: win.modelData[1] === "l" ? 0 : root.r
                        y: win.modelData[0] === "t" ? root.r : 0
                        radiusX: root.r
                        radiusY: root.r
                        direction: (win.modelData === "tl" || win.modelData === "br")
                            ? PathArc.Counterclockwise : PathArc.Clockwise
                    }
                    PathLine {
                        x: win.modelData[1] === "l" ? 0 : root.r
                        y: win.modelData[0] === "t" ? 0 : root.r
                    }
                }
            }
        }
    }
}
