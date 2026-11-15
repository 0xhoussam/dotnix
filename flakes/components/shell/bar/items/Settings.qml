import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../.."
import "../../quick"
import "../../widgets"

// Quick settings: brightness, toggles (Wi-Fi, Bluetooth, Do Not Disturb,
// night light, caffeine), power profile, screenshots / recording and the
// power menu.
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

        Text { text: "Quick Settings"; color: Theme.fg; font { pixelSize: 16; bold: true } }

        // ---- brightness
        Column {
            width: parent.width
            spacing: 4
            visible: QuickService.brightness >= 0
            Row {
                width: parent.width; height: 28
                Image {
                    layer.enabled: true; layer.effect: Tint {}
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; sourceSize: Qt.size(32, 32)
                    source: Quickshell.iconPath("display-brightness-symbolic", true)
                }
                Slider {
                    width: parent.width - 16 - 48 - 16
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    value: QuickService.brightness / 100
                    step: 0.05
                    onMoved: v => QuickService.setBrightness(Math.round(v * 100))
                }
                Text { width: 40; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: QuickService.brightness + "%"; color: Theme.fg; font.pixelSize: 12 }
            }
            Row {
                visible: QuickService.kbdBrightness >= 0
                width: parent.width; height: 28
                Image {
                    layer.enabled: true; layer.effect: Tint {}
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; sourceSize: Qt.size(32, 32)
                    source: Quickshell.iconPath("keyboard-brightness-symbolic", true)
                }
                Slider {
                    width: parent.width - 16 - 48 - 16
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    to: 1
                    step: 0.5
                    value: QuickService.kbdBrightness / 100
                    onMoved: v => QuickService.setKbd(Math.round(v * 100))
                }
                Text { width: 40; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: QuickService.kbdBrightness + "%"; color: Theme.fg; font.pixelSize: 12 }
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
            spacing: 4
            visible: QuickService.profiles.length > 0
            Text { text: "Power profile"; color: Theme.muted; font { pixelSize: 12; bold: true } }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: QuickService.profiles
                    Chip {
                        required property string modelData
                        label: QuickService.profileLabel(modelData)
                        active: QuickService.profile === modelData
                        onClicked: QuickService.setProfile(modelData)
                    }
                }
            }
            Text { visible: QuickService.profileError !== ""; width: parent.width; text: QuickService.profileError; color: Theme.danger; font.pixelSize: 11; wrapMode: Text.Wrap }
            Text { width: parent.width; text: "Resets when the charger is plugged or unplugged."; color: Theme.faint; font.pixelSize: 11 }
        }

        // ---- screenshots
        Column {
            width: parent.width
            spacing: 4
            Text { text: "Screenshot"; color: Theme.muted; font { pixelSize: 12; bold: true } }
            Row {
                spacing: 6
                Chip { label: "Region"; onClicked: { pop.open = false; QuickService.screenshot("region") } }
                Chip { label: "Window"; onClicked: { pop.open = false; QuickService.screenshot("window") } }
                Chip { label: "Screen"; onClicked: { pop.open = false; QuickService.screenshot("output") } }
            }
        }

        // ---- power menu (destructive actions need a second click)
        Column {
            width: parent.width
            spacing: 4
            Text { text: "Session"; color: Theme.muted; font { pixelSize: 12; bold: true } }
            Flow {
                width: parent.width
                spacing: 6
                component PowerChip: Chip {
                    id: pc
                    property var action
                    property bool armed: false
                    property bool needsConfirm: true
                    label: armed ? "Confirm " + text0 + "?" : text0
                    property string text0
                    property string iconName
                    icon: iconName
                    destructive: needsConfirm
                    confirm: armed
                    Timer { id: disarm; interval: 4000; onTriggered: pc.armed = false }
                    onClicked: {
                        if (needsConfirm && !armed) { armed = true; disarm.restart(); return }
                        armed = false
                        pop.open = false
                        action()
                    }
                }
                PowerChip { text0: "Lock"; iconName: "system-lock-screen-symbolic"; needsConfirm: false; action: () => QuickService.lock() }
                PowerChip { text0: "Suspend"; iconName: "system-suspend-symbolic"; needsConfirm: false; action: () => QuickService.suspend() }
                PowerChip { text0: "Log out"; iconName: "system-log-out-symbolic"; action: () => QuickService.logout() }
                PowerChip { text0: "Restart"; iconName: "system-reboot-symbolic"; action: () => QuickService.reboot() }
                PowerChip { text0: "Shut down"; iconName: "system-shutdown-symbolic"; action: () => QuickService.poweroff() }
            }
        }
    }
}
