import QtQuick
import ".."
import "../motion"

// Small round glyph button for list rows (pin, expand, remove).
Rectangle {
    id: rb
    property string glyph
    property real glyphSize: 14
    signal clicked()
    width: 28; height: 28
    radius: rbm.containsMouse ? 8 : 14
    color: rbm.containsMouse ? Theme.hover : "transparent"
    scale: rbm.pressed ? 0.9 : 1
    Behavior on radius { Anim { kind: "fastSpatial" } }
    Behavior on scale { Anim { kind: "fastSpatial" } }
    Text { anchors.centerIn: parent; text: rb.glyph; color: Theme.muted; font.pixelSize: rb.glyphSize }
    MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; onClicked: rb.clicked() }

}
