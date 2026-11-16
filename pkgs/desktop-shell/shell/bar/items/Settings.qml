import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../.."
import "../../quick"
import "../../widgets"
import "../../motion"

// Quick settings: session buttons in the header, brightness card, toggles
// (Wi-Fi, Bluetooth, Do Not Disturb, night light, caffeine), power profile,
// screenshots / recording.
Pill {
    id: root
    active: pop.open
    onClicked: pop.open = !pop.open

    Item {
        width: 16; height: 16
        Image { layer.enabled: true; layer.effect: Tint {}
            anchors.fill: parent
            sourceSize: Qt.size(32, 32)
            source: Quickshell.iconPath("emblem-system-symbolic", true)
        }
        // red dot while recording the screen
        Rectangle {
            visible: QuickService.recording
            width: 7; height: 7; radius: 4; color: "#ff5f57"
            anchors { right: parent.right; top: parent.top; rightMargin: -3; topMargin: -2 }
        }
    }

    property string armedName: ""
    property string hoverName: ""
    readonly property var net: Agents.net
    readonly property var adapter: Bluetooth.defaultAdapter

    PopupCard {
        id: pop
        anchorItem: root
        barWindow: QsWindow.window
        name: "quick"
        cardWidth: 372
        spacing: 10
        onOpenChanged: if (open) QuickService.refresh()

        // ---- header: title and the session buttons
        Item {
            width: parent.width
            height: 32
            // Doubles as the hint for the session buttons, so hovering one
            // never changes the popup's height.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 184 - 12
                elide: Text.ElideRight
                text: root.armedName !== "" ? "Confirm " + root.armedName + "?"
                    : root.hoverName !== "" ? root.hoverName : "Quick Settings"
                color: root.armedName !== "" ? Theme.danger : root.hoverName !== "" ? Theme.muted : Theme.fg
                font { pixelSize: root.armedName !== "" || root.hoverName !== "" ? 14 : 16; bold: true }
            }
            Row {
                anchors.right: parent.right
                spacing: 6
                Repeater {
                    model: [
                        { name: "Lock", icon: "system-lock-screen-symbolic,system-lock-screen,lock", confirm: false, run: () => QuickService.lock() },
                        { name: "Suspend", icon: "system-suspend-symbolic,system-suspend,media-playback-pause-symbolic", confirm: false, run: () => QuickService.suspend() },
                        { name: "Log out", icon: "system-log-out-symbolic,system-log-out,application-exit-symbolic", confirm: true, run: () => QuickService.logout() },
                        { name: "Restart", icon: "system-reboot-symbolic,system-reboot,view-refresh-symbolic", confirm: true, run: () => QuickService.reboot() },
                        { name: "Shut down", icon: "system-shutdown-symbolic,system-shutdown,application-exit", confirm: true, run: () => QuickService.poweroff() }
                    ]
                    PowerBtn {
                        required property var modelData
                        icon: modelData.icon
                        label: modelData.name
                        needsConfirm: modelData.confirm
                        onArmedChanged: root.armedName = armed ? label : (root.armedName === label ? "" : root.armedName)
                        onHoveredChanged: root.hoverName = hovered ? label : (root.hoverName === label ? "" : root.hoverName)
                        onActivated: { pop.open = false; modelData.run() }
                    }
                }
            }
        }
        // ---- brightness
        Rectangle {
            width: parent.width
            visible: QuickService.brightness >= 0
            height: sliders.implicitHeight + 24
            radius: 14
            color: Theme.surface
            Column {
                id: sliders
                x: 12; y: 12
                width: parent.width - 24
                spacing: 12
                SliderRow {
                    width: parent.width
                    icon: "display-brightness-symbolic"; label: "Display"
                    valueText: QuickService.brightness + "%"
                    value: QuickService.brightness / 100
                    step: 0.05
                    onMoved: v => QuickService.setBrightness(Math.round(v * 100))
                }
                SliderRow {
                    width: parent.width
                    visible: QuickService.kbdBrightness >= 0
                    icon: "keyboard-brightness-symbolic"; label: "Keyboard backlight"
                    valueText: QuickService.kbdBrightness + "%"
                    to: 1; step: 0.5
                    value: QuickService.kbdBrightness / 100
                    onMoved: v => QuickService.setKbd(Math.round(v * 100))
                }
            }
        }

        // ---- toggles
        Grid {
            width: parent.width
            columns: 2
            spacing: 8
            readonly property real tw: (width - spacing) / 2
            QsTile {
                width: parent.tw
                icon: "network-wireless-symbolic"; label: "Wi-Fi"
                sub: root.net && root.net.wifiEnabled ? "On" : "Off"
                active: root.net ? root.net.wifiEnabled : false
                enabled: root.net && root.net.wifiHw && root.net.wifi.length > 0
                onClicked: NetService.op("set-wifi", { on: !root.net.wifiEnabled })
            }
            QsTile {
                width: parent.tw
                icon: "bluetooth-active-symbolic"; label: "Bluetooth"
                sub: root.adapter && root.adapter.enabled ? "On" : "Off"
                active: root.adapter ? root.adapter.enabled : false
                enabled: root.adapter !== null
                onClicked: root.adapter.enabled = !root.adapter.enabled
            }
            QsTile {
                width: parent.tw
                icon: Notifs.dnd ? "notifications-disabled-symbolic" : "preferences-system-notifications-symbolic"
                label: "Do Not Disturb"; sub: Notifs.dnd ? "On" : Notifs.inQuietHours ? "Quiet hours" : "Off"
                active: Notifs.quiet
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            QsTile {
                width: parent.tw
                icon: "night-light-symbolic"; label: "Night Light"; sub: QuickService.nightLight ? "On" : "Off"
                active: QuickService.nightLight
                onClicked: QuickService.setNightLight(!QuickService.nightLight)
            }
            QsTile {
                width: parent.tw
                icon: "view-reveal-symbolic"; label: "Caffeine"; sub: QuickService.caffeine ? "Screen stays on" : "Off"
                active: QuickService.caffeine
                onClicked: QuickService.caffeine = !QuickService.caffeine
            }
            QsTile {
                width: parent.tw
                icon: "video-display-symbolic"; label: "Wallpaper"
                sub: WallpaperService.frozen ? "Paused (battery)" : WallpaperService.pauseOnBattery ? "Pauses on battery" : "Always playing"
                active: WallpaperService.pauseOnBattery
                onClicked: WallpaperService.setPauseOnBattery(!WallpaperService.pauseOnBattery)
            }
            QsTile {
                width: parent.tw
                icon: QuickService.recording ? "media-playback-stop-symbolic" : "media-record-symbolic"
                label: QuickService.recording ? "Stop recording" : "Record screen"
                sub: QuickService.hasRecorder ? (QuickService.recording ? "Saving to ~/Videos" : "wf-recorder") : "wf-recorder not found"
                active: QuickService.recording
                enabled: QuickService.hasRecorder
                onClicked: QuickService.toggleRecording()
            }
        }

        // ---- power profile
        Column {
            width: parent.width
            spacing: 6
            visible: QuickService.profiles.length > 0
            Text { leftPadding: 4; text: "Power profile"; color: Theme.muted; font { pixelSize: 12; bold: true } }
            Segmented {
                width: parent.width
                columns: 2
                options: QuickService.profiles.map(p => ({ label: QuickService.profileLabel(p), value: p }))
                current: QuickService.profile
                onPicked: v => QuickService.setProfile(v)
            }
            Text { visible: QuickService.profileError !== ""; width: parent.width; text: QuickService.profileError; color: Theme.danger; font.pixelSize: 11; wrapMode: Text.Wrap }
            Text { leftPadding: 4; width: parent.width; text: "Resets when the charger is plugged or unplugged."; color: Theme.faint; font.pixelSize: 11 }
        }

        // ---- screenshots
        Column {
            width: parent.width
            spacing: 6
            Text { leftPadding: 4; text: "Screenshot"; color: Theme.muted; font { pixelSize: 12; bold: true } }
            Row {
                spacing: 6
                readonly property real cw: (parent.width - 12) / 3
                Chip { width: parent.cw; label: "Region"; onClicked: { pop.open = false; QuickService.screenshot("region") } }
                Chip { width: parent.cw; label: "Window"; onClicked: { pop.open = false; QuickService.screenshot("window") } }
                Chip { width: parent.cw; label: "Screen"; onClicked: { pop.open = false; QuickService.screenshot("output") } }
            }
        }
    }
}
