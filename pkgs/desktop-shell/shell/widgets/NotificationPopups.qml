import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../motion"

// Transient toast popups, top-right (primary screen only).
Scope {
    PanelWindow {
        screen: Quickshell.screens[0]
        visible: Notifs.toasts.length > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notifpopups"
        anchors { top: true; right: true }
        implicitWidth: 380
        implicitHeight: list.implicitHeight + 16
        mask: Region { item: list }

        Column {
            id: list
            x: 10; y: 8
            spacing: 8
            move: Transition { Anim { properties: "y"; kind: "emphasized" } }
            Repeater {
                model: Notifs.toastGroups
                NotificationStack {
                    required property var modelData
                    n: modelData.n
                    extra: modelData.extra
                    toast: true
                    // click the stack: open the panel with the whole group
                    onMoreClicked: UiState.panelOpen = true
                }
            }
        }
    }
}
