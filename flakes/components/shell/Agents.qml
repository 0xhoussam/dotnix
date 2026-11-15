pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bridge to the `shell-agents` Rust sidecar (BlueZ pairing agent, later OBEX
// and the NetworkManager secret agent). JSON lines: events on stdout,
// answers on stdin. Quickshell kills the child when it exits, and the
// sidecar cancels every pending prompt when stdin closes, so BlueZ never
// waits on a dead UI.
Singleton {
    id: root

    // Path to the sidecar binary; set by the Nix wrapper (SHELL_AGENTS).
    readonly property string binary: Quickshell.env("SHELL_AGENTS") || ""
    // Set SHELL_AGENTS_OFF=1 to run the UI without the agents (side-by-side
    // testing next to the AGS bar, which owns the same D-Bus agent slots).
    readonly property bool enabled: binary !== "" && Quickshell.env("SHELL_AGENTS_OFF") !== "1"

    // { id, prompt } or null; at most one at a time.
    property var current: null

    function answer(kind, extra) {
        if (!current) return
        proc.write(JSON.stringify(Object.assign({ type: "answer", id: current.id, kind: kind }, extra || {})) + "\n")
    }
    function yes() { answer("yes") }
    function always() { answer("always") }
    function reject() { answer("reject") }
    function text(s) { answer("text", { text: s }) }
    function number(n) { answer("number", { number: n }) }

    Process {
        id: proc
        running: root.enabled
        stdinEnabled: true
        command: [root.binary]
        stdout: SplitParser {
            onRead: line => {
                let m
                try { m = JSON.parse(line) } catch (e) { console.warn("agents: bad line:", line); return }
                if (m.type === "prompt") root.current = { id: m.id, prompt: m.prompt }
                else if (m.type === "prompt-clear" && root.current && root.current.id === m.id) root.current = null
            }
        }
        // The agent is part of the shell: restart if it dies.
        onExited: (code, status) => {
            console.warn("agents: sidecar exited", code, status)
            root.current = null
            if (root.enabled) restart.start()
        }
    }
    Timer { id: restart; interval: 1000; onTriggered: proc.running = true }
}
