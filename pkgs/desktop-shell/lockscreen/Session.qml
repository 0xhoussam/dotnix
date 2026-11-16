pragma Singleton
import QtQuick
import Quickshell

// Shared lock state: fade-out on unlock and idle tracking for the video.
Singleton {
    id: root
    property bool leaving: false
    property real lastInput: Date.now()
    readonly property bool preview: Quickshell.env("LOCK_PREVIEW") === "1"
    readonly property string wallpaper: Quickshell.env("LOCK_WALLPAPER") || ""
    readonly property string pamService: "swaylock" // must exist in /etc/pam.d
    readonly property int idlePauseSeconds: 180
    readonly property string user: Quickshell.env("USER") || ""

    signal unlockRequested()

    function noteInput() { lastInput = Date.now() }
    // Play the outro (content slides out, blur clears, surface fades), then let
    // the lock handler release the session.
    function unlock() {
        leaving = true
        fade.start()
    }
    Timer { id: fade; interval: 1050; onTriggered: root.unlockRequested() }
}
