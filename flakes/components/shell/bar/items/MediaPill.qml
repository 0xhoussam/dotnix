import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../.."
import "../../widgets"

// Now playing: title and artist in the bar. Click play/pause, middle click
// next track, right click opens the date panel (full controls).
Pill {
    id: root
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) || players[0] || null
    visible: player !== null && !!player.trackTitle
    onClicked: mouse => {
        if (!player) return
        if (mouse.button === Qt.MiddleButton) player.next()
        else if (mouse.button === Qt.RightButton) UiState.togglePanel()
        else player.togglePlaying()
    }

    Row {
        spacing: 6
        Image { layer.enabled: true; layer.effect: Tint {}
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; sourceSize: Qt.size(28, 28)
            source: Quickshell.iconPath(root.player && root.player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic", true)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 260)
            elide: Text.ElideRight
            text: root.player ? root.player.trackTitle + (root.player.trackArtist ? " — " + root.player.trackArtist : "") : ""
            color: root.player && root.player.isPlaying ? Theme.textBar : Theme.muted
            font.pixelSize: Theme.fontSize
        }
    }
}
