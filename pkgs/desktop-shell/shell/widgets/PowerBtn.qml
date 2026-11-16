import QtQuick
import ".."

// Session button: destructive ones arm on the first click (red, 4 s) and
// run on the second. `activated` fires when the action should run.
IconBtn {
    id: root
    property string label: ""
    property bool needsConfirm: true
    property bool armed: false
    signal activated()

    destructive: needsConfirm
    confirm: armed
    Timer { id: disarm; interval: 4000; onTriggered: root.armed = false }
    onClicked: {
        if (needsConfirm && !armed) { armed = true; disarm.restart(); return }
        armed = false
        activated()
    }
}
