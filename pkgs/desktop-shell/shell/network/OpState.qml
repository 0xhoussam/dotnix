import QtQuick

// Busy label + transient error for one row (createRowOps in NetRow.tsx).
QtObject {
    id: root
    property string busy: ""
    property string error: ""
    property Timer timer: Timer { interval: 10000; onTriggered: root.error = "" }
    function showError(msg) { error = msg; timer.restart() }
    // start(cb): cb(ok, valueOrErrorText)
    function run(label, start) {
        if (busy) return
        error = ""
        busy = label
        start((ok, v) => {
            busy = ""
            if (!ok && v !== "Cancelled") showError(v)
        })
    }
}
