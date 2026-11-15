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
    // OBEX transfers: [{ path, direction, name, device, size, transferred, status }]
    property var transfers: []
    // NetworkManager snapshot from the sidecar (see nm.rs `snapshot`)
    property var net: null

    // ---- generic D-Bus calls through the sidecar --------------------------
    // call("system"|"session", dest, path, iface, method, args, timeoutMs, cb)
    // cb(ok, value): value is the reply body (array) or an error string.
    property int ridSeq: 1
    property var pending: ({})
    function argS(v) { return { t: "s", v: v } }
    function argO(v) { return { t: "o", v: v } }
    function argB(v) { return { t: "b", v: v } }
    function argV(inner) { return { t: "v", v: inner } }
    function call(bus, dest, path, iface, method, args, timeoutMs, cb) {
        const rid = ridSeq++
        if (cb) pending[rid] = cb
        proc.write(JSON.stringify({ type: "call", rid: rid, bus: bus, dest: dest, path: path, iface: iface,
            method: method, args: args || [], timeout_ms: timeoutMs || 30000 }) + "\n")
    }
    // net(op, params, cb): NetworkManager operations (netops.rs)
    function netOp(op, params, cb) {
        const rid = ridSeq++
        if (cb) pending[rid] = cb
        proc.write(JSON.stringify(Object.assign({ type: "net", rid: rid, op: op }, params || {})) + "\n")
    }
    function fields(values) { answer("fields", { fields: values }) }
    function send(obj) { proc.write(JSON.stringify(obj) + "\n") }

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
                else if (m.type === "transfers") root.transfers = m.list
                else if (m.type === "net-state") root.net = m
                else if (m.type === "reply") {
                    const cb = root.pending[m.rid]
                    delete root.pending[m.rid]
                    if (cb) cb(m.ok, m.ok ? m.value : m.error)
                }
            }
        }
        // Sidecar warnings and errors (failed registrations, keyring, ...).
        stderr: SplitParser { onRead: line => console.warn("agents:", line) }
        // The agent is part of the shell: restart if it dies.
        onExited: (code, status) => {
            console.warn("agents: sidecar exited", code, status)
            root.current = null
            if (root.enabled) restart.start()
        }
    }
    Timer { id: restart; interval: 1000; onTriggered: proc.running = true }
}
