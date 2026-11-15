import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

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
        visible: root.open
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
            implicitHeight: col.implicitHeight + 24
            radius: 16
            color: Theme.popoverBg
            border.color: Theme.border

            Column {
                id: col
                x: root.pad; y: 12
                width: root.contentWidth
                spacing: 8
            }
        }
    }
}
