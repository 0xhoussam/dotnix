import QtQuick
import Quickshell

// Big clock: hours in the accent colour, minutes in the foreground, the
// date under it. Scales down if the font is wider than the column.
Item {
    id: root
    property real maxWidth: 340
    implicitWidth: maxWidth
    implicitHeight: clockRow.height * clockRow.scale + dateText.implicitHeight + 6

    SystemClock { id: clock; precision: SystemClock.Seconds }

    Row {
        id: clockRow
        anchors.horizontalCenter: parent.horizontalCenter
        transformOrigin: Item.Top
        scale: Math.min(1, root.maxWidth / Math.max(1, implicitWidth))
        spacing: 12
        FadeText {
            text: Qt.formatTime(clock.date, "HH")
            color: Theme.cyan
            font { family: Theme.font; pixelSize: 92; weight: Font.Black }
        }
        FadeText {
            text: Qt.formatTime(clock.date, "mm")
            color: Theme.fg
            font { family: Theme.font; pixelSize: 92; weight: Font.Black }
        }
    }
    FadeText {
        id: dateText
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: clockRow.height * clockRow.scale + 6 }
        text: Qt.formatDate(clock.date, "dddd · d MMM").toUpperCase()
        color: Theme.fg
        font { family: Theme.font; pixelSize: 14; weight: Font.Bold; letterSpacing: 3 * Theme.ls }
    }
}
