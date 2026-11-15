pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import ".."

// Freeze the live video wallpaper (mpvpaper) while on battery. SIGSTOP keeps
// the last frame on screen and stops decoding; SIGCONT resumes it on AC.
// (mpvpaper itself already pauses when the wallpaper is fully covered.)
Singleton {
    id: root
    property bool pauseOnBattery: true
    readonly property bool onBattery: UPower.onBattery
    readonly property bool frozen: pauseOnBattery && onBattery

    readonly property string settingsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell/wallpaper.json"
    FileView {
        path: root.settingsPath
        blockLoading: true
        onLoaded: { try { root.pauseOnBattery = JSON.parse(text()).pauseOnBattery !== false } catch (e) { } }
    }
    Process { id: writer }
    function setPauseOnBattery(on) {
        pauseOnBattery = on
        writer.exec({ command: ["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "_",
            settingsPath, JSON.stringify({ pauseOnBattery: on })] })
    }

    Process { id: sig }
    function apply() { sig.exec(["systemctl", "--user", "kill", "-s", frozen ? "SIGSTOP" : "SIGCONT", "mpvpaper.service"]) }
    onFrozenChanged: apply()
}
