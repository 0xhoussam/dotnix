pragma Singleton
import QtQuick
import Quickshell

// Shared UI state, ported from bar/state.ts.
Singleton {
    // Date/notification panel open.
    property bool panelOpen: false
    // Number of open popups (tray menus, clipboard, network, bluetooth).
    // Holds the autohide bar visible.
    property int openPopups: 0

    function togglePanel() { panelOpen = !panelOpen }
    function closePanel() { panelOpen = false }
}
