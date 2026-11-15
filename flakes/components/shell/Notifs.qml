pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The one notification daemon (org.freedesktop.Notifications owner), shared
// by the date panel (history) and the toast popups. Replaces AstalNotifd.
Singleton {
    id: root

    property bool dnd: false
    // Newest first, for the panel list.
    readonly property var list: server.trackedNotifications.values.slice().sort((a, b) => b.id - a.id)
    // Toasts shown now (subset of tracked); popup window reads this.
    property var toasts: []
    // Arrival time per notification id (the server exposes none).
    property var arrived: ({})

    function clearAll() {
        // copy first: dismiss() mutates the live list
        server.trackedNotifications.values.slice().forEach(n => n.dismiss())
    }
    function removeToast(id) { toasts = toasts.filter(n => n.id !== id) }

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
            n.closed.connect(() => root.removeToast(n.id))
            if (root.dnd) return
            root.toasts = [n].concat(root.toasts.filter(t => t.id !== n.id))
            // Always auto-hide the toast; the notification stays in the panel.
            const t = Qt.createQmlObject('import QtQuick; Timer { repeat: false }', root)
            t.interval = n.urgency === NotificationUrgency.Critical ? 10000 : 5000
            t.triggered.connect(() => { root.removeToast(n.id); t.destroy() })
            t.start()
        }
    }
}
