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
        visible: attached.shown
        anchor.item: root.anchorItem
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        // Before each placement, stretch the anchor rect down to the bar's
        // bottom edge so the card butts up against the bar, not the pill.
        anchor.onAnchoring: {
            const it = root.anchorItem
            if (!it) return
            const top = it.mapToItem(null, 0, 0).y
            pop.anchor.rect = Qt.rect(0, 0, it.width, Math.max(it.height, Config.size - top))
        }
        implicitWidth: attached.width
        implicitHeight: attached.height
        color: "transparent"
        onVisibleChanged: if (!visible && root.open) root.open = false

        // A tall card that opens, then shrinks, should not leave the window
        // sized for the old content: the window always matches the target.
        AttachedCard {
            id: attached
            open: root.open
            cardWidth: root.cardWidth
            contentHeight: col.implicitHeight + 24

            Column {
                id: col
                x: root.pad; y: 12
                width: root.contentWidth
                spacing: 8
            }
        }
    }
}
