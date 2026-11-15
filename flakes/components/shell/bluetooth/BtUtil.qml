pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Helpers ported from bar/items/bluetooth/util.ts.
Singleton {
    function pathToAddress(path) {
        const m = /dev_([0-9A-Fa-f_]{17})/.exec(path)
        return m ? m[1].replace(/_/g, ":").toUpperCase() : path
    }
    function deviceByPath(path) {
        const adapters = Bluetooth.adapters ? Bluetooth.adapters.values : []
        for (const a of adapters)
            for (const d of a.devices.values)
                if (d.dbusPath === path) return d
        return null
    }
    function displayName(dev, fallback) {
        return dev ? (dev.name || dev.deviceName || dev.address) : (fallback || "")
    }
    function deviceIcon(dev) { return dev && dev.icon ? dev.icon + "-symbolic" : "bluetooth-symbolic" }
    function formatBytes(n) {
        const units = ["B", "KB", "MB", "GB"]
        let i = 0
        while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
        return n.toFixed(i ? 1 : 0) + " " + units[i]
    }
    // 16-bit value of a Bluetooth-base UUID, -1 otherwise.
    readonly property string base: "-0000-1000-8000-00805f9b34fb"
    function uuid16(uuid) { return uuid.toLowerCase().endsWith(base) ? parseInt(uuid.slice(0, 8), 16) : -1 }
    // Profiles worth offering an explicit connect/disconnect for.
    readonly property var connectable: [0x1108, 0x110a, 0x110b, 0x111e, 0x111f, 0x1124, 0x1812, 0x1115, 0x1116, 0x1101]
    readonly property var audioUuids: [0x1108, 0x110a, 0x110b, 0x111e, 0x111f, 0x184e, 0x1850]
    function isAudio(dev, uuids) {
        return (dev.icon || "").startsWith("audio") || (uuids || []).some(u => audioUuids.includes(uuid16(u)))
    }
    readonly property var serviceNames: ({
        0x1101: "Serial Port", 0x1103: "Dial-up Networking", 0x1105: "Object Push", 0x1106: "File Transfer",
        0x1108: "Headset", 0x110a: "Audio Source", 0x110b: "Audio Sink", 0x110c: "Remote Control Target",
        0x110d: "Advanced Audio", 0x110e: "Remote Control", 0x1112: "Headset Gateway",
        0x1115: "Personal Area Network", 0x1116: "Network Access Point", 0x1117: "Group Network",
        0x111e: "Handsfree", 0x111f: "Handsfree Gateway", 0x1124: "Input (HID)", 0x112d: "SIM Access",
        0x112f: "Phonebook Access", 0x1132: "Message Access", 0x1200: "PnP Information",
        0x1800: "Generic Access", 0x1801: "Generic Attribute", 0x180a: "Device Information",
        0x180d: "Heart Rate", 0x180f: "Battery", 0x1812: "Input (HID over GATT)",
        0x184e: "Audio Stream Control", 0x184f: "Broadcast Audio Scan", 0x1850: "Published Audio Capabilities"
    })
    function serviceName(uuid) { return serviceNames[uuid16(uuid)] || uuid }
}
