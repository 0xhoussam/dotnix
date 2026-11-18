pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../quick"

// State and output side of the screenshot tool (the UI is ScreenshotOverlay).
// start("region" | "window" | "screen") freezes the screen and opens the
// overlay; the overlay crops and annotates, saves a PNG into tmpDir and calls
// finish() to copy, file or OCR it.
Singleton {
    id: root

    property bool active: false          // overlay shown
    property string mode: "region"       // region | window | screen
    property int delay: 0                // seconds before the capture
    property int countdown: 0
    readonly property bool countingDown: countdown > 0

    readonly property string tmpDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/my-shell/shot"
    readonly property string saveDir: Quickshell.env("SCREENSHOT_DIR") || (Quickshell.env("HOME") + "/Pictures/Screenshots")
    readonly property var delays: [0, 3, 5, 10]

    function start(m, seconds) {
        if (active || countingDown) return
        mode = m
        Quickshell.execDetached(["mkdir", "-p", tmpDir])
        const d = seconds === undefined ? delay : seconds
        if (d > 0) { countdown = d; tick.start() } else active = true
    }
    function cancel() { tick.stop(); settle.stop(); countdown = 0; active = false }
    function cycleDelay() { delay = delays[(delays.indexOf(delay) + 1) % delays.length] }

    function tmpPath() { return tmpDir + "/shot-" + Date.now() + ".png" }

    function finish(path, kind) {
        Quickshell.execDetached(["bash", Quickshell.shellPath("screenshot/finish.sh"), path, saveDir, kind])
    }

    // x, y, w, h in global layout coordinates
    function record(x, y, w, h) {
        cancel()
        QuickService.recordRegion(Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h))
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1
            if (root.countdown <= 0) { tick.stop(); settle.start() }
        }
    }
    // let the countdown pill unmap before the frame is grabbed
    Timer { id: settle; interval: 250; onTriggered: root.active = true }
}
