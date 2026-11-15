pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Network helpers shared by the panel: operations through the sidecar,
// error text, persisted notification settings, and nm-applet's
// notifications (derived from successive NetworkManager snapshots).
Singleton {
    id: root
    readonly property var net: Agents.net

    // ---- operations ----------------------------------------------------------
    function errorText(e) {
        let msg = String(e).replace(/^org\.freedesktop\.\w+(\.\w+)*:\s*/, "").trim()
        if (/not authorized|NotAuthorized|PermissionDenied/i.test(msg)) return "Not authorized"
        if (/Cancel/i.test(msg)) return "Cancelled"
        return msg || "Unknown error"
    }
    // cb(ok, errorTextOrValue)
    function op(name, params, cb) {
        Agents.netOp(name, params, (ok, v) => { if (cb) cb(ok, ok ? v : root.errorText(v)) })
    }

    // ---- persisted settings ----------------------------------------------------
    readonly property var defaults: ({ notifyConnected: true, notifyDisconnected: true, notifyVpn: true, notifyAvailable: true })
    property var settings: defaults
    readonly property string settingsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell/network.json"
    FileView {
        path: root.settingsPath
        blockLoading: true
        onLoaded: { try { root.settings = Object.assign({}, root.defaults, JSON.parse(text())) } catch (e) { } }
    }
    Process { id: writer }
    function update(patch) {
        settings = Object.assign({}, settings, patch)
        writer.exec({ command: ["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "_",
            settingsPath, JSON.stringify(settings, null, 2)] })
    }

    // ---- notifications ------------------------------------------------------------
    function notify(summary, body, icon) {
        Agents.call("session", "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications", "Notify", [
                Agents.argS("Network"), { t: "u", v: 0 }, Agents.argS(icon || "network-wireless-symbolic"),
                Agents.argS(summary), Agents.argS(body || ""), { t: "as", v: [] },
                { t: "a{sv}", v: { urgency: { t: "y", v: 1 }, "desktop-entry": Agents.argS("nm-applet"),
                    transient: Agents.argB(true) } },
                { t: "i", v: -1 }], 5000)
    }

    // Disconnect reasons that aren't worth telling the user about.
    readonly property var quiet: [3, 36, 37, 38, 39, 60, 69, 70, 71, 72, 73, 74, 75, 76, 77]
    property var prevDev: null
    property var prevVpn: ({})
    property var userVpn: ({}) // uuid -> time of our own on/off
    function markUserVpn(uuid) { userVpn[uuid] = Date.now() }

    function onSnapshot(n) {
        if (!n) return
        const devs = (n.wifi || []).concat(n.devices || [])
        const cur = {}
        for (const d of devs) cur[d.path] = d
        if (prevDev) {
            for (const d of devs) {
                const o = prevDev[d.path]
                if (!o || o.state === d.state) continue
                const S = root.settings
                if (d.state === 100) {
                    if (!S.notifyConnected || (d.hotspot)) continue
                    const body = d.active ? "You are now connected to the Wi-Fi network “" + d.active.ssid + "”."
                        : "You are now connected to “" + (d.status || d.name) + "”."
                    notify("Connection Established", body, d.icon || "network-wireless-symbolic")
                } else if (d.state === 120 && S.notifyDisconnected) {
                    notify("Connection Failed", d.reasonText, "network-error-symbolic")
                } else if (o.state === 100 && (d.state === 30 || d.state === 20) && S.notifyDisconnected && !quiet.includes(d.reason)) {
                    notify("Disconnected", d.reason ? "The network connection has been disconnected: " + d.reasonText + "." : "The network connection has been disconnected.", "network-offline-symbolic")
                }
            }
        }
        prevDev = cur
        const vcur = {}
        for (const v of n.vpns || []) {
            vcur[v.uuid] = v.state
            const o = prevVpn[v.uuid]
            if (o === undefined || o === v.state || !settings.notifyVpn) continue
            const mine = Date.now() - (userVpn[v.uuid] || 0) < 8000
            if (v.state === 2) notify("VPN Connected", "VPN connection “" + v.id + "” has been successfully established.", "network-vpn-symbolic")
            else if (v.state === 4 && !mine)
                notify(o === 1 ? "VPN Connection Failed" : "VPN Disconnected", "The VPN connection “" + v.id + "” " + (o === 1 ? "failed." : "disconnected."), "network-vpn-disconnected-symbolic")
        }
        prevVpn = vcur
    }
    Connections { target: Agents; function onNetChanged() { root.onSnapshot(Agents.net) } }
}
