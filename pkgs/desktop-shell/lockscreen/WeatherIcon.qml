import QtQuick
import QtQuick.Shapes

// Weather glyphs drawn from shapes, so they do not depend on the icon theme
// (the lock process may not have one). kind: sun | partly | cloud | fog |
// rain | snow | storm.
Item {
    id: root
    property string kind: "cloud"
    property int size: 36
    implicitWidth: size
    implicitHeight: size

    component Cloud: Item {
        property color tint: Theme.fg
        x: 0; y: 0; width: 40; height: 28
        Rectangle { x: 3; y: 12; width: 34; height: 15; radius: 7.5; color: parent.tint }
        Rectangle { x: 4; y: 7; width: 15; height: 15; radius: 7.5; color: parent.tint }
        Rectangle { x: 13; y: 1; width: 20; height: 20; radius: 10; color: parent.tint }
        Rectangle { x: 24; y: 8; width: 14; height: 14; radius: 7; color: parent.tint }
    }
    component Sun: Item {
        property real d: 18
        width: 40; height: 40
        Rectangle { anchors.centerIn: parent; width: parent.d; height: width; radius: width / 2; color: Theme.cyan }
        Repeater {
            model: 8
            Rectangle {
                required property int index
                width: 3; height: 6; radius: 1.5
                color: Theme.cyan
                x: 20 - 1.5
                y: 20 - parent.d / 2 - 9
                transform: Rotation { origin.x: 1.5; origin.y: parent.d / 2 + 9; angle: index * 45 }
            }
        }
    }

    Item {
        width: 40; height: 40
        scale: root.size / 40
        transformOrigin: Item.TopLeft

        Sun { visible: root.kind === "sun"; d: 18 }
        Sun { visible: root.kind === "partly"; x: -7; y: -7; scale: 0.7; d: 18 }
        Cloud { visible: root.kind !== "sun"; x: 0; y: root.kind === "partly" || root.kind === "cloud" ? 8 : 3
            tint: root.kind === "storm" ? Theme.dim : Theme.fg }
        // fog: bars
        Repeater {
            model: root.kind === "fog" ? 3 : 0
            Rectangle { required property int index; x: 6 + (index % 2) * 4; y: 26 + index * 4.5; width: 26; height: 2.5; radius: 1.25; color: Theme.fg }
        }
        // rain: slanted drops
        Repeater {
            model: root.kind === "rain" ? 3 : 0
            Rectangle { required property int index; x: 10 + index * 9; y: 28; width: 2.5; height: 9; radius: 1.25; color: Theme.cyan; rotation: 18 }
        }
        // snow: dots
        Repeater {
            model: root.kind === "snow" ? 3 : 0
            Rectangle { required property int index; x: 10 + index * 9; y: 30 + (index % 2) * 3; width: 5; height: 5; radius: 2.5; color: Theme.fg }
        }
        // storm: bolt
        Shape {
            visible: root.kind === "storm"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.cyan; strokeColor: "transparent"
                PathPolyline { path: [Qt.point(22, 22), Qt.point(14, 33), Qt.point(20, 33), Qt.point(17, 40), Qt.point(28, 28), Qt.point(21, 28)] }
            }
        }
    }
}
