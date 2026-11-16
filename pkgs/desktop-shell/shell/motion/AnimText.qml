import QtQuick
import ".."

// Text that cross-fades when its content changes: fade out, swap, fade in.
// Don't use it for values that change many times a second.
Text {
    id: root
    property bool animate: true

    Behavior on text {
        enabled: root.animate && Theme.animScale > 0
        SequentialAnimation {
            Anim { target: root; property: "opacity"; to: 0; kind: "fastEffects" }
            PropertyAction { }
            Anim { target: root; property: "opacity"; to: 1; kind: "effects" }
        }
    }
}
