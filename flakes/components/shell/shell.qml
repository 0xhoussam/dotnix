import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "widgets"
import "bluetooth"
import "network"
import "audio"

ShellRoot {
    // Single-instance overlays on the primary screen.
    DatePanel {}
    NotificationPopups {}
    PairingDialog {}
    SecretsDialog {}
    Osd { id: osdOverlay }

    // `shell-ctl toggle volume`, `shell-ctl osd brightness`, ... (see README)
    IpcHandler {
        target: "shell"
        function toggle(name: string): void {
            if (name === "date") UiState.togglePanel()
            else UiState.requestPanel(name)
        }
        function osd(kind: string): void {
            if (kind === "brightness") osdOverlay.brightness()
        }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Bar { screen: perScreen.modelData }
            ScreenCorners { screen: perScreen.modelData }
        }
    }
}
