import QtQuick
import Quickshell
import "../../widgets"

// Quick-settings button. Stub, like the AGS version.
Pill {
    onClicked: console.log("Settings: TODO")
    Image { layer.enabled: true; layer.effect: Tint {}
        width: 16; height: 16
        sourceSize: Qt.size(32, 32)
        source: Quickshell.iconPath("emblem-system-symbolic", true)
    }
}
