import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.."
import "../../motion"

// Hyprland workspaces: an empty workspace is a faint dot, an occupied one
// shows the icons of its windows (up to three, then "+N"), the focused one
// sits on an accent pill, an urgent one is tinted red. Click switches;
// scrolling over the strip steps through workspaces.
//
// Layout is computed (not a Row) so every slot has a known target position.
// That lets one accent indicator slide between slots with a stretchy trail,
// the way caelestia-dots/shell does it: the leading edge moves first, the
// trailing edge follows 1.5x slower.
Item {
    id: root
    implicitWidth: totalW
    implicitHeight: 24
    Behavior on implicitWidth { Anim { } }

    readonly property int gap: 4
    readonly property var list: Hyprland.workspaces.values
        .filter(w => w.id > 0)
        .sort((a, b) => a.id - b.id)
    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property int activeIdx: list.findIndex(w => w.id === focusedId)

    function windowCount(w) { return w.toplevels.values.length }
    function slotWidth(w) {
        const n = windowCount(w)
        if (n === 0) return w.id === focusedId ? 26 : 9
        const k = Math.min(3, n)
        let iw = k * 14 + (k - 1) * 3
        if (n > 3) iw += 3 + 6 * (1 + String(n - 3).length)
        return iw + 12
    }
    function slotHeight(w) { return windowCount(w) > 0 ? 22 : 9 }

    // Target geometry per slot, ignoring in-flight animations.
    readonly property var geom: {
        let x = 0
        const out = []
        for (const w of list) {
            const sw = slotWidth(w)
            out.push({ x: x, w: sw, h: slotHeight(w), occupied: windowCount(w) > 0 })
            x += sw + gap
        }
        return out
    }
    readonly property real totalW: geom.length ? geom[geom.length - 1].x + geom[geom.length - 1].w : 0

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

    function runAnim() {
        if (activeIdx < 0 || activeIdx >= geom.length) return
        const g = geom[activeIdx]
        const s = g.x, e = g.x + g.w
        if (!indicator.placed) {
            indicator.start = s
            indicator.end = e
            indicator.placed = true
            return
        }
        const lead = Theme.durations.spatial
        const trail = lead * 1.5
        const goingLeft = s < indicator.start
        startAnim.stop(); endAnim.stop()
        startAnim.to = s; endAnim.to = e
        startAnim.duration = goingLeft ? lead : trail
        endAnim.duration = goingLeft ? trail : lead
        startAnim.start(); endAnim.start()
    }
    onActiveIdxChanged: runAnim()
    onGeomChanged: runAnim()

    // The sliding accent pill, drawn under the slots.
    Rectangle {
        id: indicator
        property bool placed: false
        property real start: 0
        property real end: 0
        readonly property var g: root.activeIdx >= 0 && root.activeIdx < root.geom.length ? root.geom[root.activeIdx] : null
        readonly property bool hasWindows: g ? g.occupied : false

        visible: placed && g !== null
        x: start
        width: Math.max(0, end - start)
        height: g ? g.h : 9
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: hasWindows ? Theme.accentSoft : Theme.accent
        border.width: hasWindows ? 1 : 0
        border.color: Theme.accent
        Behavior on height { Anim { } }
        Behavior on color { CAnim { } }

        Anim on start { id: startAnim; running: false }
        Anim on end { id: endAnim; running: false }
    }

    Repeater {
        model: ScriptModel { values: root.list }

        Rectangle {
            id: ws
            required property var modelData
            required property int index
            readonly property bool active: modelData.id === root.focusedId
            readonly property var tops: modelData.toplevels.values
            readonly property var g: root.geom[index] ?? ({ x: 0, w: 9, h: 9 })

            anchors.verticalCenter: parent.verticalCenter
            x: g.x
            width: g.w
            height: g.h
            radius: height / 2
            // The focused slot is painted by the indicator underneath.
            color: modelData.urgent ? Theme.danger
                : active ? "transparent"
                : tops.length > 0 ? (area.containsMouse ? Theme.surfaceHover : Theme.surface)
                : area.containsMouse ? Theme.fg : Theme.faint
            scale: area.pressed ? 0.88 : 1
            opacity: 0
            Component.onCompleted: opacity = 1

            Behavior on x { Anim { } }
            Behavior on width { Anim { } }
            Behavior on height { Anim { } }
            Behavior on scale { Anim { kind: "fastSpatial" } }
            Behavior on opacity { Anim { kind: "effects" } }
            Behavior on color { CAnim { } }

            Row {
                id: icons
                anchors.centerIn: parent
                spacing: 3
                visible: opacity > 0
                opacity: ws.tops.length > 0 ? 1 : 0
                Behavior on opacity { Anim { kind: "effects" } }
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

    // scroll over the strip: previous / next workspace
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + (wheel.angleDelta.y > 0 ? "e-1" : "e+1") + "\" })")
    }
}
