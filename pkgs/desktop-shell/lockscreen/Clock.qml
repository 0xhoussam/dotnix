import QtQuick
import Quickshell
import "."

// Big clock top-left with a cyan "— SUNDAY · OCTOBER 11" line under it.
Column {
    SystemClock { id: clock; precision: SystemClock.Seconds }
    Text {
        text: Qt.formatTime(clock.date, "HH:mm")
        color: Theme.fg
        font { family: Theme.font; pixelSize: 92; weight: Font.Black; letterSpacing: 2 * Theme.ls }
    }
    Row {
        leftPadding: 4
        spacing: 12
        Rectangle { width: 26; height: 2; color: Theme.cyan; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: Qt.formatDate(clock.date, "dddd · MMMM d").toUpperCase()
            color: Theme.cyan
            font { family: Theme.font; pixelSize: 13; weight: Font.Black; letterSpacing: 3 * Theme.ls }
        }
    }
}
