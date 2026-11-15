pragma Singleton
import QtQuick
import Quickshell

// Shared UI state, ported from bar/state.ts.
Singleton {
    // Date/notification panel open.
    property bool panelOpen: false
    // Popups register here (PopupCard, tray menus); any one being open keeps
    // the autohide bar visible. Derived, so a destroyed popup cannot leave
    // the bar stuck.
    property var popups: []
    readonly property bool anyPopupOpen: popups.some(p => p.open)
    function register(p) { popups = popups.concat([p]) }
    function unregister(p) { popups = popups.filter(x => x !== p) }
    // Volume panel open (the volume OSD stays quiet while it is).
    property bool volumePanelOpen: false
    // Clipboard overlay (widgets/ClipboardPanel.qml)
    property bool clipboardOpen: false

    // IPC / keybind request to toggle a bar panel by name ("volume", "quick", ...);
    // only the bar on the focused monitor reacts.
    signal panelRequested(string name)
    function requestPanel(name) { panelRequested(name) }

    function togglePanel() { panelOpen = !panelOpen }
    function closePanel() { panelOpen = false }
}
