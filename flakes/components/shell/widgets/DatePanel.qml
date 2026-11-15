import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

// GNOME-style shade: notifications (left) + calendar / world clocks (right).
// Fullscreen transparent overlay; click outside or Escape to close.
Scope {
    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        visible: UiState.panelOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "datepanel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }

        onVisibleChanged: if (visible) { panel.opacity = 0; panel.y = -12; open.start() }
        ParallelAnimation {
            id: open
            NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 220 }
            NumberAnimation { target: panel; property: "y"; to: 6; duration: 220; easing.type: Easing.OutCubic }
        }

        MouseArea { anchors.fill: parent; onClicked: UiState.closePanel() }

        Rectangle {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            width: row.implicitWidth + 24
            height: row.implicitHeight + 24
            radius: 14
            color: Theme.popoverBg
            border.color: Qt.rgba(1, 1, 1, 0.07)
            focus: true
            Keys.onEscapePressed: UiState.closePanel()
            MouseArea { anchors.fill: parent } // swallow clicks on the card

            RowLayout {
                id: row
                anchors { fill: parent; margins: 12 }
                spacing: 12

                // ---- notifications column
                ColumnLayout {
                    Layout.preferredWidth: 380
                    Layout.alignment: Qt.AlignTop
                    spacing: 10
                    Media { Layout.fillWidth: true }
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 420
                        clip: true
                        spacing: 8
                        model: Notifs.list
                        delegate: NotificationCard { required property var modelData; n: modelData }
                        Text {
                            anchors.centerIn: parent
                            visible: Notifs.list.length === 0
                            text: "No Notifications"
                            color: Theme.muted; font.pixelSize: 14
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "Do Not Disturb"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                        Switch { checked: Notifs.dnd; onToggled: Notifs.dnd = checked }
                        Rectangle {
                            implicitWidth: clearText.implicitWidth + 28; implicitHeight: 28; radius: 14
                            color: clearArea.containsMouse ? Theme.hover : Qt.rgba(1, 1, 1, 0.08)
                            Text { id: clearText; anchors.centerIn: parent; text: "Clear"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                            MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.clearAll() }
                        }
                    }
                }

                // ---- calendar column
                ColumnLayout {
                    Layout.preferredWidth: 300
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    SystemClock { id: clock; precision: SystemClock.Minutes }
                    Column {
                        Text { text: Qt.formatDate(clock.date, "dddd"); color: Theme.fg; font.pixelSize: 15 }
                        Text { text: Qt.formatDate(clock.date, "MMMM d yyyy"); color: Theme.fg; font.pixelSize: 22; font.bold: true }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        DayOfWeekRow { Layout.fillWidth: true; locale: Qt.locale(); delegate: Text { required property string shortName; text: shortName; color: Theme.muted; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12 } }
                        MonthGrid {
                            Layout.fillWidth: true
                            month: clock.date.getMonth()
                            year: clock.date.getFullYear()
                            locale: Qt.locale()
                            delegate: Rectangle {
                                required property var model
                                implicitHeight: 28
                                radius: 14
                                color: model.today ? Theme.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: model.day
                                    color: model.today ? Theme.accentFg : (model.month === clock.date.getMonth() ? Theme.fg : Theme.faint)
                                    font.pixelSize: Theme.fontSize
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: events.implicitHeight + 24
                        radius: 12; color: Theme.card
                        Column {
                            id: events
                            anchors { fill: parent; margins: 12 }
                            Text { text: "Today"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                            Text { text: "No Events"; color: Theme.muted; font.italic: true; font.pixelSize: Theme.fontSize }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: world.implicitHeight + 24
                        radius: 12; color: Theme.card
                        id: worldCard
        // "HH:mm" per world clock, via `date` (QML has no tz-by-name API).
                        property var times: []
                        Process {
                            id: tzProc
                            command: ["bash", "-c", "for tz in \"$@\"; do TZ=$tz date +%H:%M; done", "_"]
                                .concat(Config.worldClocks.map(c => c.tz))
                            stdout: StdioCollector { onStreamFinished: worldCard.times = text.trim().split("\n") }
                        }
                        Timer { interval: 60000; running: win.visible; repeat: true; triggeredOnStart: true; onTriggered: tzProc.running = true }
                        Column {
                            id: world
                            anchors { fill: parent; margins: 12 }
                            spacing: 6
                            Text { text: "World Clocks"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                            Repeater {
                                model: Config.worldClocks
                                Row {
                                    required property var modelData
                                    required property int index
                                    width: world.width
                                    Text { width: parent.width - t.implicitWidth; text: modelData.label; color: Theme.fg; font.pixelSize: Theme.fontSize }
                                    Text { id: t; text: (worldCard.times[index] || ""); color: Theme.muted; font.bold: true; font.pixelSize: Theme.fontSize }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
