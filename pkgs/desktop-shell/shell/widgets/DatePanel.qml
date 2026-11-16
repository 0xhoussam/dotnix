import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../motion"

// GNOME-style shade: notifications (left) + calendar / world clocks (right).
// Fullscreen transparent overlay; click outside or Escape to close.
Scope {
    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        // stays mapped while the card fades out, but click-through then
        visible: UiState.panelOpen || panel.shown
        mask: UiState.panelOpen ? null : closedMask
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "datepanel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }

        Region { id: closedMask }
        Connections {
            target: UiState
            function onPanelOpenChanged() { if (UiState.panelOpen) InfoService.refresh() }
        }

        MouseArea { anchors.fill: parent; onClicked: UiState.closePanel() }

        // Grows out of the bar's bottom edge (the bar is the top Config.size px).
        AttachedCard {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: Config.size
            open: UiState.panelOpen
            cardWidth: row.implicitWidth + 24
            contentHeight: row.implicitHeight + 24
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
                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 420
                        contentHeight: groupsCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: groupsCol
                            width: parent.width
                            spacing: 10
                            Text {
                                visible: Notifs.items.length === 0
                                width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 170
                                text: "No Notifications"
                                color: Theme.muted; font.pixelSize: 14
                            }
                            Repeater {
                                model: Notifs.groups
                                Column {
                                    id: grp
                                    required property var modelData
                                    width: groupsCol.width
                                    spacing: 6
                                    readonly property bool folded: modelData.items.length > 1 && !Notifs.expanded[modelData.app]
                                    // group header: app, count, collapse, clear
                                    Item {
                                        width: parent.width; height: 24
                                        MouseArea { anchors.fill: parent; onClicked: Notifs.toggleGroup(grp.modelData.app) }
                                        Text { x: 2; anchors.verticalCenter: parent.verticalCenter; text: (grp.folded ? "▸ " : "▾ ") + grp.modelData.app + "  ·  " + grp.modelData.items.length; color: Theme.muted; font { pixelSize: 12; bold: true } }
                                        Text {
                                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                            text: "Clear"; color: Theme.muted; font.pixelSize: 11
                                            MouseArea { anchors { fill: parent; margins: -4 } onClicked: Notifs.clearGroup(grp.modelData.app) }
                                        }
                                    }
                                    // Folded: the newest card with the rest stacked behind it.
                                    // Expanded: every card. The body's height glides between
                                    // the two and the cards fade down one after another.
                                    Item {
                                        id: body
                                        width: parent.width
                                        clip: true
                                        height: grp.folded ? stack.height : cards.implicitHeight
                                        Behavior on height { Anim { kind: "emphasized" } }

                                        NotificationStack {
                                            id: stack
                                            visible: opacity > 0
                                            opacity: grp.folded ? 1 : 0
                                            Behavior on opacity { Anim { kind: "fastEffects" } }
                                            n: grp.modelData.items[0]
                                            extra: grp.modelData.items.length - 1
                                            onMoreClicked: Notifs.toggleGroup(grp.modelData.app)
                                        }
                                        Column {
                                            id: cards
                                            width: parent.width
                                            spacing: 6
                                            enabled: !grp.folded // folded: the invisible cards must not catch clicks meant for the stack
                                            Repeater {
                                                model: grp.modelData.items
                                                NotificationCard {
                                                    id: nc
                                                    required property var modelData
                                                    required property int index
                                                    n: modelData
                                                    opacity: grp.folded ? 0 : 1
                                                    transform: Translate { y: grp.folded ? -10 : 0; Behavior on y { Anim { kind: "emphasized" } } }
                                                    // stagger on expand, instant on fold
                                                    Behavior on opacity {
                                                        SequentialAnimation {
                                                            PauseAnimation { duration: grp.folded ? 0 : Math.min(nc.index, 6) * 40 }
                                                            Anim { target: nc; property: "opacity"; kind: "effects" }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.field }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "Do Not Disturb"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                        Toggle { checked: Notifs.dnd; onToggled: v => Notifs.dnd = v }
                        Rectangle {
                            implicitWidth: clearText.implicitWidth + 28; implicitHeight: 28; radius: 14
                            color: clearArea.containsMouse ? Theme.hover : Theme.field
                            Text { id: clearText; anchors.centerIn: parent; text: "Clear all"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                            MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; onClicked: Notifs.clearAll() }
                        }
                    }
                    // quiet hours: toasts are held back between the two times
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: "Quiet hours"; color: Theme.fg; font.pixelSize: 12; Layout.fillWidth: true }
                        component Step: Rectangle {
                            id: step
                            property string sign: "−"
                            signal clicked()
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: sm.containsMouse ? Theme.hover : Theme.field
                            Text { anchors.centerIn: parent; text: step.sign; color: Theme.fg; font.pixelSize: 12 }
                            MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; onClicked: step.clicked() }
                        }
                        Step { sign: "−"; onClicked: Notifs.quietStart = (Notifs.quietStart + 1410) % 1440 }
                        Text { text: Notifs.clockText(Notifs.quietStart); color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
                        Step { sign: "+"; onClicked: Notifs.quietStart = (Notifs.quietStart + 30) % 1440 }
                        Text { text: "→"; color: Theme.muted; font.pixelSize: 12 }
                        Step { sign: "−"; onClicked: Notifs.quietEnd = (Notifs.quietEnd + 1410) % 1440 }
                        Text { text: Notifs.clockText(Notifs.quietEnd); color: Theme.fg; font { pixelSize: 12; family: "monospace" } }
                        Step { sign: "+"; onClicked: Notifs.quietEnd = (Notifs.quietEnd + 30) % 1440 }
                        Toggle { checked: Notifs.quietEnabled; onToggled: v => Notifs.quietEnabled = v }
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
                            Layout.preferredHeight: 6 * 30
                            month: clock.date.getMonth()
                            year: clock.date.getFullYear()
                            locale: Qt.locale()
                            delegate: Rectangle {
                                required property var model
                                implicitWidth: 36
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

                    // ---- weather
                    Rectangle {
                        visible: InfoService.weather !== null || InfoService.weatherError !== ""
                        Layout.fillWidth: true
                        implicitHeight: wcol.implicitHeight + 24
                        radius: 12; color: Theme.card
                        Column {
                            id: wcol
                            anchors { fill: parent; margins: 12 }
                            spacing: 8
                            Row {
                                visible: InfoService.weather !== null
                                spacing: 12
                                Image {
                                    layer.enabled: true; layer.effect: Tint {}
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 36; height: 36; sourceSize: Qt.size(72, 72)
                                    source: InfoService.weather ? Quickshell.iconPath(InfoService.iconFor(InfoService.weather.code), true) : ""
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: InfoService.weather ? InfoService.weather.temp + "°C  " + InfoService.weather.desc : ""; color: Theme.fg; font { pixelSize: 15; bold: true } }
                                    Text { text: InfoService.weather ? (InfoService.weather.area ? InfoService.weather.area + " · " : "") + "feels " + InfoService.weather.feels + "° · " + InfoService.weather.humidity + "% · " + InfoService.weather.wind + " km/h" : ""; color: Theme.muted; font.pixelSize: 11 }
                                }
                            }
                            Row {
                                visible: InfoService.weather !== null
                                spacing: 0
                                Repeater {
                                    model: InfoService.weather ? InfoService.weather.days : []
                                    Column {
                                        required property var modelData
                                        width: (wcol.width) / 3
                                        spacing: 2
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd"); color: Theme.muted; font.pixelSize: 11 }
                                        Image {
                                            layer.enabled: true; layer.effect: Tint {}
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 20; height: 20; sourceSize: Qt.size(40, 40)
                                            source: Quickshell.iconPath(InfoService.iconFor(modelData.code), true)
                                        }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.max + "° / " + modelData.min + "°"; color: Theme.fg; font.pixelSize: 11 }
                                    }
                                }
                            }
                            Text { visible: InfoService.weather === null; text: InfoService.weatherError; color: Theme.muted; font.pixelSize: 12 }
                        }
                    }

                    // ---- calendar events (today and the next two days)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: events.implicitHeight + 24
                        radius: 12; color: Theme.card
                        Column {
                            id: events
                            anchors { fill: parent; margins: 12 }
                            spacing: 4
                            Text { text: "Events"; color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize }
                            Text {
                                visible: InfoService.calendarState === "not-configured"
                                width: parent.width; wrapMode: Text.Wrap
                                text: "Add your Google Calendar's secret iCal address to ~/.config/my-shell/calendar.url (Calendar settings → Integrate calendar → Secret address in iCal format)."
                                color: Theme.muted; font.pixelSize: 11
                            }
                            Text { visible: InfoService.calendarState === "error"; width: parent.width; wrapMode: Text.Wrap; text: InfoService.calendarError; color: Theme.danger; font.pixelSize: 11 }
                            Text { visible: InfoService.calendarState === "loading" && InfoService.events.length === 0; text: "Loading…"; color: Theme.muted; font.pixelSize: 12 }
                            Text { visible: InfoService.calendarState === "ok" && InfoService.events.length === 0; text: "No events in the next three days"; color: Theme.muted; font { italic: true; pixelSize: 12 } }
                            Repeater {
                                model: InfoService.events.slice(0, 8)
                                Column {
                                    required property var modelData
                                    required property int index
                                    width: events.width
                                    readonly property date start: new Date(modelData.start)
                                    readonly property string day: Qt.formatDate(start, "yyyyMMdd") === Qt.formatDate(new Date(), "yyyyMMdd") ? "Today"
                                        : Qt.formatDate(start, "ddd d MMM")
                                    readonly property string prevDay: index > 0 ? (Qt.formatDate(new Date(InfoService.events[index - 1].start), "yyyyMMdd") === Qt.formatDate(new Date(), "yyyyMMdd") ? "Today" : Qt.formatDate(new Date(InfoService.events[index - 1].start), "ddd d MMM")) : ""
                                    Text { visible: parent.day !== parent.prevDay; text: parent.day; color: Theme.muted; font { pixelSize: 11; bold: true } topPadding: 4 }
                                    Row {
                                        spacing: 8
                                        Text { text: modelData.allDay ? "All day" : Qt.formatTime(parent.parent.start, "HH:mm"); color: Theme.accent; font { pixelSize: 12; family: "monospace" } width: 52 }
                                        Text { text: modelData.title; color: Theme.fg; font.pixelSize: 12; elide: Text.ElideRight; width: events.width - 60 }
                                    }
                                }
                            }
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
