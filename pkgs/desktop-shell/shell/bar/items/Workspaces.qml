import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.."

// Hyprland workspaces: an empty workspace is a faint dot, an occupied one
// shows the icons of its windows (up to three, then "+N"), the focused one
// sits on an accent pill, an urgent one is tinted red. Click switches;
// scrolling over the strip steps through workspaces.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: 24

    // window class -> icon path
    function iconFor(top) {
        const cls = ((top.lastIpcObject && top.lastIpcObject["class"]) || "").toLowerCase()
        const mapped = Config.taskbarIcons[cls]
        let entry = null
        try { entry = DesktopEntries.heuristicLookup(cls) } catch (e) { }
        return (mapped && Quickshell.iconPath(mapped, true))
            || (entry && entry.icon && Quickshell.iconPath(entry.icon, true))
            || (cls && Quickshell.iconPath(cls, true))
            || Quickshell.iconPath(Config.defaultAppIcon, true)
    }

    Row {
        id: row
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            // Drop special (negative id) workspaces, sort ascending.
            model: Hyprland.workspaces.values
                .filter(w => w.id > 0)
                .sort((a, b) => a.id - b.id)

            Rectangle {
                id: ws
                required property var modelData
                readonly property bool active: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                readonly property var tops: modelData.toplevels.values
                readonly property int shown: Math.min(3, tops.length)
                anchors.verticalCenter: parent.verticalCenter
                height: tops.length > 0 ? 22 : 9
                width: tops.length > 0 ? icons.implicitWidth + 12 : (active ? 26 : 9)
                radius: height / 2
                color: modelData.urgent ? Theme.danger
                    : active ? (tops.length > 0 ? Theme.accentSoft : Theme.accent)
                    : tops.length > 0 ? (area.containsMouse ? Theme.surfaceHover : Theme.surface)
                    : area.containsMouse ? Theme.fg : Theme.faint
                border.width: active && tops.length > 0 ? 1 : 0
                border.color: Theme.accent
                Behavior on width { NumberAnimation { duration: 160 } }
                Behavior on color { ColorAnimation { duration: 160 } }

                Row {
                    id: icons
                    anchors.centerIn: parent
                    spacing: 3
                    visible: ws.tops.length > 0
                    Repeater {
                        model: ws.tops.slice(0, 3)
                        Image {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; sourceSize: Qt.size(28, 28)
                            source: root.iconFor(modelData)
                        }
                    }
                    Text {
                        visible: ws.tops.length > 3
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + (ws.tops.length - 3)
                        color: Theme.fg; font.pixelSize: 10; font.bold: true
                    }
                }
                MouseArea {
                    id: area
                    anchors { fill: parent; margins: -2 }
                    hoverEnabled: true
                    // Hyprland's config is Lua: legacy `workspace N` dispatches fail here.
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws.modelData.id + " })")
                }
            }
        }
    }

    // scroll over the strip: previous / next workspace
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (wheel.angleDelta.y > 0 ? "e-1" : "e+1") + "\" })")
    }
}
