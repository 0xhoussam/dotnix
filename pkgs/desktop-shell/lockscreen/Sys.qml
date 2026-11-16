pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Live data for the lock panel: CPU / memory / disk / temperature, uptime,
// OS name, weather and the notification history the shell wrote. All of it
// is read locally or fetched here; the lock process shares nothing with the
// shell. Timers only run while the lock is up (the process lives that long).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/my-shell"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/my-shell"
    readonly property string user: Quickshell.env("USER") || ""
    readonly property string wm: (Quickshell.env("XDG_CURRENT_DESKTOP") || "Wayland").split(":")[0]

    // Notification text on a lock screen is visible to anyone who can see the
    // screen. Titles are shown; message bodies never are.
    readonly property bool showNotifTitles: true

    // ---- resources (0..1) ---------------------------------------------------
    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property real temp: -1         // deg C, -1 = unknown
    property string uptime: ""
    property string osName: ""

    property real _prevTotal: 0
    property real _prevIdle: 0
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + f[4]
            const total = f.reduce((a, b) => a + b, 0)
            if (root._prevTotal > 0 && total > root._prevTotal)
                root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._prevIdle) / (total - root._prevTotal)))
            root._prevTotal = total
            root._prevIdle = idle
        }
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const total = Number((/MemTotal:\s+(\d+)/.exec(t) || [])[1])
            const avail = Number((/MemAvailable:\s+(\d+)/.exec(t) || [])[1])
            if (total > 0) root.mem = Math.max(0, Math.min(1, 1 - avail / total))
        }
    }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const s = Math.floor(Number(text().split(" ")[0]))
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
            root.uptime = d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m"
        }
    }
    FileView {
        id: osRelease
        path: "/etc/os-release"
        blockLoading: true
        onLoaded: root.osName = ((/^PRETTY_NAME="?([^"\n]*)"?/m.exec(text()) || [])[1]) || "Linux"
    }
    Process {
        id: dfProc
        command: ["bash", "-c", "df --output=pcent / | tail -1"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); if (!isNaN(v)) root.disk = v / 100 } }
    }
    Process {
        id: tempProc
        command: ["bash", "-c", "for d in /sys/class/hwmon/hwmon*; do case $(cat $d/name 2>/dev/null) in k10temp|coretemp|zenpower|cpu_thermal) cat $d/temp1_input; break;; esac; done"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); root.temp = isNaN(v) ? -1 : Math.round(v / 1000) } }
    }
    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { stat.reload(); meminfo.reload(); uptimeFile.reload(); tempProc.running = true }
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: dfProc.running = true }

    // ---- battery ------------------------------------------------------------
    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery
    readonly property int battery: Math.round(UPower.displayDevice.percentage * 100)
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)

    // ---- weather (wttr.in; a place in my-shell/weather.txt, else by IP) -----
    property var weather: null
    FileView { id: place; path: root.configDir + "/weather.txt"; blockLoading: true; printErrors: false }
    Process {
        id: wproc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const c = j.current_condition[0]
                    root.weather = {
                        temp: c.temp_C, feels: c.FeelsLikeC, desc: c.weatherDesc[0].value, code: parseInt(c.weatherCode),
                        days: j.weather.slice(0, 3).map(d => {
                            const h = d.hourly[Math.min(4, d.hourly.length - 1)]
                            return { date: d.date, max: d.maxtempC, min: d.mintempC, code: parseInt(h.weatherCode) }
                        })
                    }
                } catch (e) { }
            }
        }
    }
    function fetchWeather() {
        let p = ""
        try { p = encodeURIComponent(place.text().trim()) } catch (e) { }
        wproc.exec(["curl", "-sf", "-m", "10", "wttr.in/" + p + "?format=j1"])
    }
    Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.fetchWeather() }
    function weatherKind(code) {
        if ([113].includes(code)) return "sun"
        if ([116].includes(code)) return "partly"
        if ([119, 122].includes(code)) return "cloud"
        if ([143, 248, 260].includes(code)) return "fog"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 377].includes(code)) return "snow"
        if ([200, 386, 389, 392, 395].includes(code)) return "storm"
        return "rain"
    }

    // ~/.face exists (the avatar only loads it then, so a missing one is silent)
    property bool hasFace: false
    FileView { path: root.home + "/.face"; printErrors: false; onLoaded: root.hasFace = true }

    // ---- notification history (written by the shell) ------------------------
    property var notifs: []
    FileView {
        path: root.stateDir + "/notifications.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.notifs = JSON.parse(text()).sort((a, b) => b.time - a.time).slice(0, 30) } catch (e) { root.notifs = [] }
        }
        onLoadFailed: root.notifs = []
    }
}
