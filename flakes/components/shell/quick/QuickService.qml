pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".."

// State behind the quick settings panel. Everything is read when the panel
// opens (`refresh()`), never polled.
Singleton {
    id: root

    // ---- brightness -----------------------------------------------------------
    property int brightness: -1   // percent, -1 = no backlight
    property int kbdBrightness: -1
    readonly property string kbdDevice: "tpacpi::kbd_backlight"
    Process {
        id: bProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector { onStreamFinished: { const p = parseInt(text.trim().split(",")[3]); root.brightness = isNaN(p) ? -1 : p } }
    }
    Process {
        id: kProc
        command: ["brightnessctl", "-d", root.kbdDevice, "-m"]
        stdout: StdioCollector { onStreamFinished: { const p = parseInt(text.trim().split(",")[3]); root.kbdBrightness = isNaN(p) ? -1 : p } }
    }
    Process { id: setB }
    Process { id: setK }
    function setBrightness(pct) { brightness = pct; setB.exec(["brightnessctl", "set", Math.max(1, pct) + "%"]) }
    function setKbd(pct) { kbdBrightness = pct; setK.exec(["brightnessctl", "-d", kbdDevice, "set", pct + "%"]) }

    // ---- night light (hyprsunset user service) ------------------------------------
    property bool nightLight: false
    Process {
        id: nlProc
        command: ["systemctl", "--user", "is-active", "hyprsunset"]
        stdout: StdioCollector { onStreamFinished: root.nightLight = text.trim() === "active" }
    }
    Process { id: nlSet; onExited: nlProc.running = true }
    function setNightLight(on) { nightLight = on; nlSet.exec(["systemctl", "--user", on ? "start" : "stop", "hyprsunset"]) }

    // ---- caffeine: hold an idle inhibitor while on (resets with the shell) ----------
    property bool caffeine: false
    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle", "--who=Quick Settings", "--why=Caffeine", "--mode=block", "sleep", "infinity"]
    }

    // ---- power profile (tuned). acpid switches profile on AC changes, so a
    // manual choice holds until the charger is plugged or unplugged. -------------------
    property string profile: ""
    property var profiles: []
    readonly property var wanted: ["laptop-battery-maxpower", "laptop-ac-balanced", "balanced-battery", "balanced", "powersave", "throughput-performance"]
    property string profileError: ""
    Process {
        id: pList
        command: ["tuned-adm", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const have = text.split("\n").map(l => /^- (\S+)/.exec(l)).filter(m => m).map(m => m[1])
                root.profiles = root.wanted.filter(w => have.includes(w))
            }
        }
    }
    Process {
        id: pActive
        command: ["tuned-adm", "active"]
        stdout: StdioCollector { onStreamFinished: root.profile = (/profile: (\S+)/.exec(text) || [])[1] || "" }
    }
    Process {
        id: pSet
        stderr: StdioCollector { id: pErr }
        onExited: (code) => { root.profileError = code === 0 ? "" : (pErr.text.trim().split("\n").pop() || "Could not change the profile"); pActive.running = true }
    }
    function setProfile(name) { profileError = ""; pSet.exec(["tuned-adm", "profile", name]) }
    function profileLabel(p) {
        return ({ "laptop-battery-maxpower": "Battery saver", "laptop-ac-balanced": "Balanced (AC)", "balanced-battery": "Balanced (battery)",
                  "balanced": "Balanced", "powersave": "Power save", "throughput-performance": "Performance" })[p] || p
    }

    // ---- screen recording (wf-recorder, when present) ------------------------------------
    property bool hasRecorder: false
    property bool recording: false
    Process {
        id: rec
        running: root.recording
        command: ["bash", "-c", 'mkdir -p "$HOME/Videos" && exec wf-recorder -f "$HOME/Videos/recording-$(date +%F_%H-%M-%S).mp4"']
        onExited: root.recording = false
    }
    Process {
        id: recCheck
        command: ["bash", "-c", "command -v wf-recorder"]
        onExited: (code) => root.hasRecorder = code === 0
    }
    function toggleRecording() { if (recording) rec.signal(2); else recording = true } // SIGINT finalises the file

    // ---- screenshots (hyprshot) -------------------------------------------------------------
    function screenshot(mode) { Quickshell.execDetached(["hyprshot", "-m", mode]) }

    // ---- power menu -----------------------------------------------------------------------------
    function lock() { Quickshell.execDetached([Quickshell.env("SHELL_LOCK_CMD") || "lock-screen"]) }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]) }
    // Hyprland's config is Lua: dispatchers are Lua calls
    function logout() { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]) }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]) }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]) }

    function refresh() {
        bProc.running = true; kProc.running = true; nlProc.running = true
        pList.running = true; pActive.running = true; recCheck.running = true
    }
}
