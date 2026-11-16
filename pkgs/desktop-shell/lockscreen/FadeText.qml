import QtQuick

// Text that cross-fades when its content changes.
Text {
    id: root
    Behavior on text {
        SequentialAnimation {
            Anim { target: root; property: "opacity"; to: 0; kind: "fastEffects" }
            PropertyAction { }
            Anim { target: root; property: "opacity"; to: 1; kind: "effects" }
        }
    }
}
