import QtQuick
import Quickshell.Hyprland
import "../.."

// Hyprland workspaces as dots: faint per workspace, brighter when occupied,
// elongated accent pill for the focused one.
Row {
    spacing: 4
    Repeater {
        // Drop special (negative id) workspaces, sort ascending.
        model: Hyprland.workspaces.values
            .filter(w => w.id > 0)
            .sort((a, b) => a.id - b.id)

        Rectangle {
            id: dot
            required property var modelData
            readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
            readonly property bool occupied: modelData.toplevels.values.length > 0
            anchors.verticalCenter: parent.verticalCenter
            height: 9
            width: active ? 26 : 9
            radius: 9999
            color: active ? Theme.accent : area.containsMouse ? Theme.fg : occupied ? Theme.muted : Theme.faint
            Behavior on width { NumberAnimation { duration: 160 } }
            Behavior on color { ColorAnimation { duration: 160 } }
            MouseArea {
                id: area
                anchors { fill: parent; margins: -3 }
                hoverEnabled: true
                // Hyprland's config is Lua: legacy `workspace N` dispatches fail here.
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.modelData.id + " })")
            }
        }
    }
}
