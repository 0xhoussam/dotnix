import QtQuick
import QtMultimedia
import Quickshell
import "."

// Looped, muted video (or still image); dark gradient when unset.
Item {
    id: root
    readonly property string path: Session.wallpaper
    readonly property bool isVideo: /\.(mp4|webm|mkv|mov|m4v)$/i.test(path)

    Rectangle {
        anchors.fill: parent
        visible: !root.path
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.gradTop }
            GradientStop { position: 0.55; color: Theme.gradMid }
            GradientStop { position: 1; color: Theme.gradBottom }
        }
    }
    Image {
        anchors.fill: parent
        visible: root.path && !root.isVideo
        source: visible ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectCrop
    }
    Loader {
        anchors.fill: parent
        active: root.path !== "" && root.isVideo
        sourceComponent: Item {
            MediaPlayer {
                id: player
                source: "file://" + root.path
                loops: MediaPlayer.Infinite
                videoOutput: out
                Component.onCompleted: play()
                onErrorOccurred: (e, msg) => console.error("lock: video error:", msg)
            }
            VideoOutput { id: out; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
            // Pause after idle (saves battery while locked); input resumes.
            Timer {
                interval: 10000; running: true; repeat: true
                onTriggered: {
                    const idle = (Date.now() - Session.lastInput) / 1000
                    if (idle >= Session.idlePauseSeconds && player.playbackState === MediaPlayer.PlayingState) player.pause()
                    else if (idle < Session.idlePauseSeconds && player.playbackState === MediaPlayer.PausedState) player.play()
                }
            }
            Connections {
                target: Session
                function onLastInputChanged() { if (player.playbackState === MediaPlayer.PausedState) player.play() }
            }
        }
    }
}
