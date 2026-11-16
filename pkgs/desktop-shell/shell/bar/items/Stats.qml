import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import "../../motion"
import "../../widgets"

// System monitor: CPU, memory, temperature, disk and network speed. Sampled
// once a second only while the popup is open (no polling otherwise).
Pill {
    id: root
    active: pop.open
    onClicked: pop.open = !pop.open

    Image { layer.enabled: true; layer.effect: Tint {}
        width: 16; height: 16
        sourceSize: Qt.size(32, 32)
        source: Quickshell.iconPath("utilities-system-monitor-symbolic", true)
    }

    // ---- sampling ----
    property real cpu: 0          // 0..1
    property real memUsed: 0      // kB
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real temp: -1        // °C
    property real diskUsed: 0     // kB
    property real diskTotal: 0
    property real rx: 0           // B/s
    property real tx: 0
    property var last: null       // previous cpu idle/total and net totals
    property var history: []      // cpu history for the sparkline

    function bytes(n) {
        if (n < 1024) return n.toFixed(0) + " B"
        if (n < 1048576) return (n / 1024).toFixed(0) + " KB"
        if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB"
        return (n / 1073741824).toFixed(2) + " GB"
    }
    function kb(n) { return bytes(n * 1024) }

    Process {
        id: sample
        // one tiny shell script: raw counters, parsed here
        command: ["bash", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo; " +
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1 | sed 's/^/TEMP /'; " +
            "df -Pk / | tail -1 | awk '{print \"DISK\", $2, $3}'; " +
            "awk 'NR>2 && $1 !~ /^lo:/ {rx+=$2; tx+=$10} END {print \"NET\", rx, tx}' /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now()
                let idle = 0, total = 0, rx = 0, tx = 0
                const mem = {}
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/)
                    if (f[0] === "cpu") { const v = f.slice(1).map(Number); idle = v[3] + (v[4] || 0); total = v.reduce((a, b) => a + b, 0) }
                    else if (f[0].endsWith(":")) mem[f[0].slice(0, -1)] = Number(f[1])
                    else if (f[0] === "TEMP") root.temp = Number(f[1]) / 1000
                    else if (f[0] === "DISK") { root.diskTotal = Number(f[1]); root.diskUsed = Number(f[2]) }
                    else if (f[0] === "NET") { rx = Number(f[1]); tx = Number(f[2]) }
                }
                root.memTotal = mem.MemTotal || 0
                root.memUsed = (mem.MemTotal || 0) - (mem.MemAvailable || 0)
                root.swapTotal = mem.SwapTotal || 0
                root.swapUsed = (mem.SwapTotal || 0) - (mem.SwapFree || 0)
                if (root.last) {
                    const dt = (now - root.last.t) / 1000
                    const dTotal = total - root.last.total
                    root.cpu = dTotal > 0 ? 1 - (idle - root.last.idle) / dTotal : 0
                    root.rx = Math.max(0, (rx - root.last.rx) / dt)
                    root.tx = Math.max(0, (tx - root.last.tx) / dt)
                    root.history = root.history.concat([root.cpu]).slice(-40)
                }
                root.last = { t: now, idle: idle, total: total, rx: rx, tx: tx }
            }
        }
    }
    Timer {
        interval: 1000; repeat: true; running: pop.open; triggeredOnStart: true
        onTriggered: sample.running = true
    }

    PopupCard {
        id: pop
        anchorItem: root
        barWindow: QsWindow.window
        name: "stats"
        cardWidth: 340
        spacing: 10
        onOpenChanged: if (!open) { root.last = null; root.history = [] }

        Text { text: "System"; color: Theme.fg; font { pixelSize: 16; bold: true } }

        component Meter: Column {
            property string label
            property string value
            property real fraction: 0
            property color tint: Theme.accent
            width: pop.contentWidth
            spacing: 4
            Row {
                width: parent.width
                Text { text: label; color: Theme.muted; font { pixelSize: 12; bold: true } width: parent.width - vt.implicitWidth }
                Text { id: vt; text: value; color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
            }
            Rectangle {
                width: parent.width; height: 6; radius: 3; color: Theme.track
                Rectangle { height: parent.height; radius: 3; width: parent.width * Math.max(0, Math.min(1, fraction)); color: tint
                    Behavior on width { Anim { kind: "standard" } } }
            }
        }

        Meter { label: "CPU"; value: Math.round(root.cpu * 100) + "%"; fraction: root.cpu; tint: root.cpu > 0.85 ? Theme.warn : Theme.accent }
        // CPU history
        Row {
            width: parent.width; height: 28; spacing: 1
            Repeater {
                model: root.history
                Rectangle {
                    required property real modelData
                    anchors.bottom: parent.bottom
                    width: (pop.contentWidth - 39) / 40; height: Math.max(2, 28 * modelData); radius: 1
                    color: Theme.accentBar
                }
            }
        }
        Meter { label: "Memory"; value: root.kb(root.memUsed) + " / " + root.kb(root.memTotal); fraction: root.memTotal ? root.memUsed / root.memTotal : 0 }
        Meter { visible: root.swapTotal > 0; label: "Swap"; value: root.kb(root.swapUsed) + " / " + root.kb(root.swapTotal); fraction: root.swapTotal ? root.swapUsed / root.swapTotal : 0 }
        Meter { label: "Disk (/)"; value: root.kb(root.diskUsed) + " / " + root.kb(root.diskTotal); fraction: root.diskTotal ? root.diskUsed / root.diskTotal : 0 }
        Meter { visible: root.temp >= 0; label: "Temperature"; value: root.temp.toFixed(0) + " °C"; fraction: root.temp / 100; tint: root.temp > 85 ? Theme.danger : root.temp > 70 ? Theme.warn : Theme.accent }
        Row {
            spacing: 24
            Text { text: "↓ " + root.bytes(root.rx) + "/s"; color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
            Text { text: "↑ " + root.bytes(root.tx) + "/s"; color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
        }
    }
}
