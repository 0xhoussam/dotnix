import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../.."
import "../../quick"
import "../../widgets"

// Battery pill + popup: charge, state, time left, power draw, health and
// the power profile.
Pill {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev && dev.ready && dev.isLaptopBattery
    visible: present
    active: pop.open
    onClicked: pop.open = !pop.open

    readonly property string stateName: dev ? UPowerDeviceState.toString(dev.state) : ""
    readonly property bool charging: stateName === "Charging" || stateName === "PendingCharge"
    readonly property bool full: stateName === "FullyCharged"

    function dur(sec) {
        if (!sec || sec <= 0) return ""
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }
    readonly property string headline: {
        if (!dev) return ""
        if (full) return "Fully charged"
        if (charging) { const t = dur(dev.timeToFull); return t ? "Charging · " + t + " to full" : "Charging" }
        const t = dur(dev.timeToEmpty)
        return t ? t + " remaining" : "On battery"
    }

    Row {
        spacing: 4
        Image { layer.enabled: true; layer.effect: Tint {}
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: root.dev ? Quickshell.iconPath(root.dev.iconName, true) : ""
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dev ? Math.round(root.dev.percentage * 100) + "%" : ""
            color: root.dev && root.dev.percentage < 0.15 && !root.charging ? Theme.danger : Theme.textBar
            font.pixelSize: Theme.fontSize
        }
    }

    PopupCard {
        id: pop
        anchorItem: root
        barWindow: QsWindow.window
        name: "battery"
        cardWidth: 340
        spacing: 10
        onOpenChanged: if (open) QuickService.refresh()

        Row {
            spacing: 12
            Text { text: root.dev ? Math.round(root.dev.percentage * 100) + "%" : ""; color: Theme.fg; font { pixelSize: 30; bold: true } }
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.headline; color: Theme.muted; font.pixelSize: Theme.fontSize }
        }
        Rectangle {
            width: parent.width; height: 8; radius: 4; color: Theme.track
            Rectangle {
                height: parent.height; radius: 4
                width: parent.width * (root.dev ? root.dev.percentage : 0)
                color: root.charging ? Theme.success : (root.dev && root.dev.percentage < 0.15 ? Theme.danger : Theme.accent)
            }
        }
        Column {
            width: parent.width
            spacing: 3
            Repeater {
                model: root.dev ? [
                    ["State", root.stateName.replace(/([A-Z])/g, " $1").trim()],
                    ["Power", root.dev.changeRate > 0 ? root.dev.changeRate.toFixed(1) + " W" : "—"],
                    ["Energy", root.dev.energy.toFixed(1) + " / " + root.dev.energyCapacity.toFixed(1) + " Wh"],
                    ["Health", root.dev.healthSupported ? Math.round(root.dev.healthPercentage) + "%" : "—"]
                ] : []
                Row {
                    required property var modelData
                    spacing: 12
                    Text { text: modelData[0]; color: Theme.muted; font.pixelSize: 12; width: 64 }
                    Text { text: modelData[1]; color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
                }
            }
        }
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
        }
    }
}
