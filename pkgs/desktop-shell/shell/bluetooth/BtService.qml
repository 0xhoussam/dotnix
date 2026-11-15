pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import ".."

// Bluetooth side effects and shared state, ported from bluetooth/services.ts,
// rfkill.ts and the settings/error helpers in util.ts.
Singleton {
    id: root

    // ---- persisted settings -------------------------------------------------
    readonly property var defaults: ({
        notifyConnections: true, notifyLowBattery: true, controllerWakelock: true,
        acceptFromTrusted: false, showUnnamed: false, autoConnect: []
    })
    property var settings: defaults
    readonly property string settingsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell/bluetooth.json"

    FileView {
        id: file
        path: root.settingsPath
        blockLoading: true
        onLoaded: {
            try { root.settings = Object.assign({}, root.defaults, JSON.parse(text())) } catch (e) { }
        }
    }
    Process { id: writer }
    function update(patch) {
        settings = Object.assign({}, settings, patch)
        writer.exec({ command: ["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "_",
            settingsPath, JSON.stringify(settings, null, 2)] })
    }
    function toggleAutoConnect(address, on) {
        const list = settings.autoConnect.filter(a => a !== address)
        update({ autoConnect: on ? list.concat([address]) : list })
    }

    // ---- rfkill ----------------------------------------------------------------
    // A hard block (hardware switch / airplane key) can't be undone from
    // software; a soft block is lifted before powering the adapter on.
    property bool rfSoft: false
    property bool rfHard: false
    Process {
        id: rfList
        command: ["rfkill", "-J", "-o", "TYPE,SOFT,HARD"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const bt = (JSON.parse(text).rfkilldevices || []).filter(d => d.type === "bluetooth")
                    root.rfSoft = bt.length > 0 && bt.every(d => d.soft === "blocked")
                    root.rfHard = bt.length > 0 && bt.every(d => d.hard === "blocked")
                } catch (e) { }
            }
        }
    }
    Process {
        // prints a line on every change (and the current state at start)
        running: true
        command: ["rfkill", "event"]
        stdout: SplitParser { onRead: rfList.running = true }
    }
    Process { id: unblocker; command: ["rfkill", "unblock", "bluetooth"]; onExited: rfList.running = true }
    function unblock() { if (rfSoft) unblocker.running = true }

    // ---- errors ----------------------------------------------------------------
    // BlueZ >= 5.62 returns machine-readable strings, older ones strerror() text.
    readonly property var errorMap: ({
        "Protocol not available": "No audio endpoints registered (is PipeWire running?)",
        "br-connection-profile-unavailable": "No audio endpoints registered (is PipeWire running?)",
        "Input/output error": "Input/output error", "I/O error": "Input/output error",
        "br-connection-create-socket": "Input/output error", "le-connection-create-socket": "Input/output error",
        "Host is down": "Device did not respond", "br-connection-page-timeout": "Device did not respond",
        "le-connection-abort-by-local": "Connection aborted", "br-connection-unknown": "Unknown error",
        "Authentication Failed": "Authentication failed", "Authentication Rejected": "Pairing rejected",
        "Authentication Canceled": "Pairing cancelled", "Authentication Timeout": "Pairing timed out",
        "Connection Attempt Failed": "Connection attempt failed", "Already Exists": "Already paired",
        "Does Not Exist": "Device not found", "In Progress": "Already in progress",
        "Not Ready": "Adapter not ready", "Timeout was reached": "Timed out"
    })
    function isCancelled(e) { return /Cancel|br-connection-canceled/i.test(String(e)) }
    function errorText(e) {
        // "org.bluez.Error.Failed: br-connection-page-timeout"
        const msg = String(e).replace(/^.*?org\.bluez\.Error\.\w+:\s*/, "").replace(/^[\w.]+Error[\w.]*:\s*/, "").trim()
        return errorMap[msg] || msg || "Unknown error"
    }

    // ---- BlueZ calls --------------------------------------------------------------
    function bluez(dev, method, args, timeout, cb) {
        Agents.call("system", "org.bluez", dev.dbusPath, "org.bluez.Device1", method, args, timeout, cb)
    }
    function pair(dev, cb) { bluez(dev, "Pair", [], 120000, cb) }
    function cancelPairing(dev) { bluez(dev, "CancelPairing", [], 5000) }
    function connect(dev, cb) { bluez(dev, "Connect", [], 60000, cb) }
    function disconnect(dev, cb) { bluez(dev, "Disconnect", [], 30000, cb) }
    function connectProfile(dev, uuid, cb) { bluez(dev, "ConnectProfile", [Agents.argS(uuid)], 60000, cb) }
    function disconnectProfile(dev, uuid, cb) { bluez(dev, "DisconnectProfile", [Agents.argS(uuid)], 30000, cb) }
    function remove(dev, cb) {
        Agents.call("system", "org.bluez", dev.adapter.dbusPath, "org.bluez.Adapter1", "RemoveDevice",
            [Agents.argO(dev.dbusPath)], 30000, cb)
    }
    // Pair (if needed), trust, then connect: the same sequence blueman uses.
    function pairTrustConnect(dev, cb) {
        const finish = (ok, v) => cb(ok, v)
        const doConnect = () => {
            if (!dev.trusted) dev.trusted = true
            if (dev.connected) return finish(true)
            connect(dev, finish)
        }
        if (dev.paired) doConnect()
        else pair(dev, (ok, v) => ok ? doConnect() : finish(false, v))
    }
    function getAll(dev, cb) {
        Agents.call("system", "org.bluez", dev.dbusPath, "org.freedesktop.DBus.Properties", "GetAll",
            [Agents.argS("org.bluez.Device1")], 5000, (ok, v) => cb(ok ? v[0] : {}))
    }
    function setAlias(dev, name) {
        Agents.call("system", "org.bluez", dev.dbusPath, "org.freedesktop.DBus.Properties", "Set",
            [Agents.argS("org.bluez.Device1"), Agents.argS("Alias"), Agents.argV(Agents.argS(name))], 5000)
    }

    // ---- notifications ---------------------------------------------------------------
    function notify(summary, body, icon, urgency) {
        Agents.call("session", "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications", "Notify", [
                Agents.argS("Bluetooth"), { t: "u", v: 0 }, Agents.argS(icon || "bluetooth-active-symbolic"),
                Agents.argS(summary), Agents.argS(body || ""), { t: "as", v: [] },
                { t: "a{sv}", v: { urgency: { t: "y", v: urgency === undefined ? 1 : urgency },
                    "desktop-entry": Agents.argS("bluetooth"), transient: Agents.argB(true) } },
                { t: "i", v: -1 }], 5000)
    }

    function displayName(d) { return d ? (d.name || d.deviceName || d.address) : "" }
    function isGameController(d) { return d.icon === "input-gaming" }

    readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var adapter: Bluetooth.defaultAdapter

    // Per-device watchers: connect / low-battery notifications.
    readonly property int lowBattery: 20
    Instantiator {
        model: Bluetooth.devices
        delegate: QtObject {
            id: w
            required property var modelData
            property bool connected: modelData.connected
            property real battery: modelData.batteryAvailable ? modelData.battery : -1
            property bool lowWarned: false
            onConnectedChanged: {
                if (!root.settings.notifyConnections) return
                const name = root.displayName(modelData)
                if (connected) {
                    const pct = battery >= 0 ? Math.round(battery * 100) : -1
                    root.notify(name, pct >= 0 ? "Connected · battery " + pct + "%" : "Connected",
                        (modelData.icon || "bluetooth") + "-symbolic")
                } else {
                    root.notify(name, "Disconnected", (modelData.icon || "bluetooth") + "-symbolic")
                    lowWarned = false
                }
                root.updateWakelock()
            }
            onBatteryChanged: {
                if (battery < 0) return
                const pct = Math.round(battery * 100)
                if (pct > root.lowBattery) { lowWarned = false; return }
                if (connected && !lowWarned && root.settings.notifyLowBattery) {
                    lowWarned = true
                    root.notify(root.displayName(modelData) + " battery low", pct + "% remaining",
                        "battery-caution-symbolic", 2)
                }
            }
        }
    }

    // ---- game controller idle inhibitor ----------------------------------------------------
    // While a controller is connected, hold a logind idle inhibitor so
    // hypridle doesn't dim/lock mid-game.
    property bool wantWakelock: false
    function updateWakelock() {
        wantWakelock = settings.controllerWakelock && devices.some(d => d.connected && isGameController(d))
    }
    onSettingsChanged: updateWakelock()
    Process {
        running: root.wantWakelock
        command: ["systemd-inhibit", "--what=idle", "--who=Bluetooth", "--why=Game controller connected",
            "--mode=block", "sleep", "infinity"]
    }

    // ---- auto-connect -------------------------------------------------------------------------
    // Devices flagged in the device panel are connected when the adapter
    // powers on and retried every minute while powered.
    property var inFlight: ({})
    function autoConnect() {
        if (!adapter || !adapter.enabled) return
        for (const address of settings.autoConnect) {
            const d = devices.find(x => x.address === address)
            if (!d || !d.paired || d.connected || inFlight[address]) continue
            inFlight[address] = true
            connect(d, () => { delete inFlight[address] })
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.autoConnect() }
    Timer { interval: 3000; running: true; onTriggered: root.autoConnect() }
    Timer { id: poweredDelay; interval: 1500; onTriggered: root.autoConnect() }
    Connections {
        target: root.adapter
        function onEnabledChanged() { if (root.adapter.enabled) poweredDelay.restart() }
    }
}
