pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The one notification daemon (org.freedesktop.Notifications owner), shared
// by the date panel (history, grouped by app) and the toast popups.
//  - Do Not Disturb: manual switch plus optional quiet hours (toasts are
//    suppressed, notifications still land in the panel).
//  - History survives a shell restart: ~/.local/state/my-shell/notifications.json
//    (mode 0600, at most 200 entries, nothing older than 14 days). It holds
//    message bodies, so it is private to the user.
Singleton {
    id: root

    // ---- do not disturb ------------------------------------------------------
    property bool dnd: false                       // manual
    property bool quietEnabled: false              // scheduled
    property int quietStart: 22 * 60               // minutes after midnight
    property int quietEnd: 7 * 60
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property int nowMinutes: clock.date.getHours() * 60 + clock.date.getMinutes()
    readonly property bool inQuietHours: quietEnabled && (quietStart <= quietEnd
        ? nowMinutes >= quietStart && nowMinutes < quietEnd
        : nowMinutes >= quietStart || nowMinutes < quietEnd)
    readonly property bool quiet: dnd || inQuietHours

    function clockText(min) { return String(Math.floor(min / 60) % 24).padStart(2, "0") + ":" + String(min % 60).padStart(2, "0") }

    // ---- state files ----------------------------------------------------------------
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/my-shell"
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/my-shell"
    Process { id: writer }
    function writeFile(path, text) {
        // umask 077: private to the user
        writer.exec(["bash", "-c", 'umask 077; mkdir -p "$(dirname "$1")"; printf %s "$2" > "$1.tmp" && mv "$1.tmp" "$1"', "_", path, text])
    }
    FileView {
        path: root.configDir + "/notifications.json"
        blockLoading: true
        onLoaded: {
            try {
                const j = JSON.parse(text())
                root.dnd = !!j.dnd
                if (j.quiet) { root.quietEnabled = !!j.quiet.enabled; root.quietStart = j.quiet.start; root.quietEnd = j.quiet.end }
            } catch (e) { }
        }
    }
    function saveSettings() {
        writeFile(configDir + "/notifications.json", JSON.stringify({ dnd: dnd, quiet: { enabled: quietEnabled, start: quietStart, end: quietEnd } }))
    }
    onDndChanged: saveSettings()
    onQuietEnabledChanged: saveSettings()
    onQuietStartChanged: saveSettings()
    onQuietEndChanged: saveSettings()

    // ---- items: live (tracked by the server) + restored from the last run ------------------
    property var restored: []                       // plain objects, same fields as a notification
    property var arrived: ({})                       // live id -> Date
    readonly property var live: server.trackedNotifications.values
    function timeOf(n) { return n.time ? n.time : (arrived[n.id] || new Date(0)).getTime() }
    readonly property var items: live.concat(restored).sort((a, b) => timeOf(b) - timeOf(a))
    // grouped by app, newest group first
    readonly property var groups: {
        const map = {}, order = []
        for (const n of items) {
            const k = n.appName || "Notification"
            if (!map[k]) { map[k] = { app: k, icon: n.appIcon || n.desktopEntry || "", items: [] }; order.push(map[k]) }
            map[k].items.push(n)
        }
        return order
    }
    property var collapsed: ({})
    function toggleGroup(app) { const c = Object.assign({}, collapsed); c[app] = !c[app]; collapsed = c }

    FileView {
        path: root.stateDir + "/notifications.json"
        blockLoading: true
        onLoaded: {
            try {
                const cutoff = Date.now() - 14 * 24 * 3600 * 1000
                root.restored = JSON.parse(text()).filter(e => e.time > cutoff)
                    .map(e => Object.assign({ actions: [], restored: true, hints: ({}) }, e))
            } catch (e) { }
        }
    }
    Timer { id: saveHistory; interval: 600; onTriggered: root.persist() }
    function persist() {
        const out = items.slice(0, 200).map(n => ({
            appName: n.appName, appIcon: n.appIcon, desktopEntry: n.desktopEntry, summary: n.summary, body: n.body,
            image: n.image, urgency: Number(n.urgency), time: timeOf(n)
        }))
        writeFile(stateDir + "/notifications.json", JSON.stringify(out))
    }

    function dismiss(n) {
        if (n.dismiss) n.dismiss()
        else { restored = restored.filter(r => r !== n); saveHistory.restart() }
    }
    function clearAll() {
        // copy first: dismiss() mutates the live list
        server.trackedNotifications.values.slice().forEach(n => n.dismiss())
        restored = []
        saveHistory.restart()
    }
    function clearGroup(app) { items.filter(n => (n.appName || "Notification") === app).forEach(n => dismiss(n)) }

    // ---- toasts -------------------------------------------------------------------------------
    property var toasts: []
    function removeToast(id) { toasts = toasts.filter(n => n.id !== id) }
    function toastMs(n) {
        // expireTimeout: a positive value is the sender's wish (seconds; senders using ms are > 60)
        const e = n.expireTimeout
        if (e > 0) return e > 60 ? e : e * 1000
        return n.urgency === NotificationUrgency.Critical ? 10000 : 5000
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            root.arrived[n.id] = new Date()
            n.closed.connect(() => { root.removeToast(n.id); saveHistory.restart() })
            saveHistory.restart()
            if (root.quiet) return
            root.toasts = [n].concat(root.toasts.filter(t => t.id !== n.id))
            // The toast hides after the sender's timeout; the notification stays in the panel.
            const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false }', root)
            t.interval = root.toastMs(n)
            t.triggered.connect(() => { root.removeToast(n.id); t.destroy() })
            t.start()
        }
    }
}
