pragma Singleton
import QtQuick

// Field validators named by the sidecar's secret prompts; null = valid.
QtObject {
    readonly property var hex: /^[0-9a-fA-F]*$/
    readonly property var printable: /^[\x20-\x7e]*$/
    function check(kind, v) {
        switch (kind) {
        case "psk":
            if (v.length === 64 && hex.test(v)) return null
            if (v.length < 8 || v.length > 63) return "Must be 8–63 characters (or 64 hex digits)"
            if (!printable.test(v)) return "Only printable ASCII characters are allowed"
            return null
        case "nonempty": return v ? null : "Required"
        case "wep":
            if ((v.length === 10 || v.length === 26) && hex.test(v)) return null
            if ((v.length === 5 || v.length === 13) && printable.test(v)) return null
            return "WEP keys are 5/13 characters or 10/26 hex digits"
        case "wep-passphrase": return v && v.length <= 64 ? null : "1–64 characters"
        case "pin": return /^\d{4,8}$/.test(v) ? null : "4–8 digits"
        default: return null
        }
    }
}
