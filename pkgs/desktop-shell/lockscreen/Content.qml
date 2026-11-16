import QtQuick
import QtQuick.Layouts

// The three columns of the panel, laid out at a fixed logical size (the
// surface scales it to the screen): weather / fetch / media on the left,
// clock / avatar / password in the middle, resources / notifications right.
Item {
    id: root
    readonly property int logicalWidth: 1040
    readonly property int logicalHeight: 640
    width: logicalWidth
    height: logicalHeight

    RowLayout {
        anchors { fill: parent; margins: 18 }
        spacing: 16

        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: 12
            WeatherCard { Layout.fillWidth: true }
            FetchCard { Layout.fillWidth: true }
            MediaCard { Layout.fillWidth: true; Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.preferredWidth: 372
            Layout.fillHeight: true
            spacing: 14
            Item { Layout.fillHeight: true }
            CenterClock { Layout.alignment: Qt.AlignHCenter; maxWidth: 360 }
            Avatar { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6 }
            PasswordInput { id: pw; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 300; Layout.preferredHeight: 52 }
            StateMessage { Layout.fillWidth: true; text: pw.status; error: pw.error !== "" }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            spacing: 12
            ResourcesCard { Layout.fillWidth: true }
            NotifDock { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
