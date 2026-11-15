import QtQuick
import Quickshell
import "bar"
import "widgets"
import "bluetooth"
import "network"

ShellRoot {
    // Single-instance overlays on the primary screen.
    DatePanel {}
    NotificationPopups {}
    PairingDialog {}
    SecretsDialog {}

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
