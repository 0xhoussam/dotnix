import QtQuick
import Quickshell
import "../.."
import "../../widgets"

// Clipboard history: the icon toggles the clipboard panel (widgets/ClipboardPanel.qml).
Pill {
    active: UiState.clipboardOpen
    onClicked: UiState.clipboardOpen = !UiState.clipboardOpen

    Image { layer.enabled: true; layer.effect: Tint {}
        width: 16; height: 16
        sourceSize: Qt.size(32, 32)
        source: Quickshell.iconPath("edit-paste-symbolic", true)
    }
}
