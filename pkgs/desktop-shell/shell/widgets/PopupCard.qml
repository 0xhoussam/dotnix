import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "../motion"

// Dropdown under a bar item: anchored popup window, rounded card, content
// column, and a focus grab so a click anywhere else closes it. Declare the
// contents as children. `open` is registered with UiState, which derives
// "some popup is open" (keeps the autohide bar shown) from it, so a popup
// destroyed while open cannot leave the bar stuck.
Scope {
    id: root
    property Item anchorItem
    // the bar window hosting the anchor (`barWindow: QsWindow.window` at the use site)
    property var barWindow: null
    // name for IPC toggling (`shell-ctl toggle <name>`)
    property string name: ""
    property int cardWidth: 392
    property int pad: 16
    property alias spacing: col.spacing
    property bool open: false
    readonly property real contentWidth: cardWidth - 2 * pad
    default property alias content: col.data

    Connections {
        target: UiState
        function onPanelRequested(n) {
            if (!root.name || n !== root.name) return
            const mon = Hyprland.focusedMonitor
            const scr = root.barWindow ? root.barWindow.screen : null
            if (!mon || !scr || mon.name === scr.name) root.open = !root.open
        }
    }

    Component.onCompleted: UiState.register(root)
    Component.onDestruction: UiState.unregister(root)

    HyprlandFocusGrab {
        windows: root.barWindow ? [pop, root.barWindow] : [pop]
        active: root.open
        onCleared: root.open = false
    }

    PopupWindow {
        id: pop
        // stays mapped until the close animation has finished
        visible: root.open || card.opacity > 0
        anchor.item: root.anchorItem
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        implicitWidth: root.cardWidth
        implicitHeight: card.implicitHeight
        color: "transparent"
        onVisibleChanged: if (!visible && root.open) root.open = false

        Rectangle {
            id: card
            width: parent.width
            // The window is sized to the target height at once; the card
            // animates to it, so content that grows or shrinks glides.
            readonly property real targetHeight: col.implicitHeight + 24
            implicitHeight: targetHeight
            height: targetHeight
            Behavior on height { Anim { kind: "emphasized" } }
            radius: 16
            color: Theme.popoverBg
            border.color: Theme.border
            // open/close: drop in from the bar, fade, scale from the top edge
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            transformOrigin: Item.Top
            transform: Translate { y: root.open ? 0 : -8; Behavior on y { Anim { kind: "emphasized" } } }
            Behavior on opacity { Anim { kind: "effects" } }
            Behavior on scale { Anim { kind: "emphasized" } }
            clip: true

            Column {
                id: col
                x: root.pad; y: 12
                width: root.contentWidth
                spacing: 8
            }
        }
    }
}
