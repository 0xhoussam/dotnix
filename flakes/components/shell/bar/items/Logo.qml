import QtQuick
import Quickshell

// NixOS logo at the far left of the bar. Static, non-interactive.
Item {
    implicitWidth: 32
    implicitHeight: 18
    Image {
        x: 6
        width: 18; height: 18
        sourceSize: Qt.size(36, 36)
        source: Quickshell.iconPath("nix-snowflake-white", true)
    }
}
