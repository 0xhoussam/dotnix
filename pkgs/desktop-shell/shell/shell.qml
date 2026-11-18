import QtQuick
import Quickshell
import Quickshell.Io
import "bar"
import "widgets"
import "bluetooth"
import "network"
import "audio"
import "quick"
import "screenshot"

ShellRoot {
    // start the wallpaper power control (a singleton is created on first use)
    Component.onCompleted: WallpaperService.apply()

    // Single-instance overlays on the primary screen.
    DatePanel {}
    NotificationPopups {}
    PairingDialog {}
    SecretsDialog {}
    Osd { id: osdOverlay }
    ClipboardPanel {}
    ScreenshotOverlay {}

    // `shell-ctl toggle volume`, `shell-ctl osd brightness`, ... (see README)
    IpcHandler {
        target: "shell"
        function toggle(name: string): void {
            if (name === "date") UiState.togglePanel()
            else if (name === "clipboard") UiState.clipboardOpen = !UiState.clipboardOpen
            else UiState.requestPanel(name)
        }
        // `shell-ctl shell screenshot region|window|screen`, `... screenshotIn region 5`
        function screenshot(mode: string): void { ScreenshotService.start(mode) }
        function screenshotIn(mode: string, seconds: int): void { ScreenshotService.start(mode, seconds) }
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
