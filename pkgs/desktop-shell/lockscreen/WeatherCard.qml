import QtQuick

// Current conditions and a three-day outlook.
Card {
    id: root
    readonly property var w: Sys.weather
    implicitHeight: col.implicitHeight + 36

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 6

        FadeText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.w ? root.w.desc : "Weather unavailable"
            color: Theme.dim
            elide: Text.ElideRight
            font { family: Theme.font; pixelSize: 12 }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            FadeText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.w ? root.w.temp + "°" : "--"
                color: Theme.cyan
                font { family: Theme.font; pixelSize: 46; weight: Font.Black }
            }
            WeatherIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.w !== null
                size: 44
                kind: root.w ? Sys.weatherKind(root.w.code) : "cloud"
            }
        }
        FadeText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.w !== null
            text: root.w ? "Feels like " + root.w.feels + "°  ·  H " + root.w.days[0].max + "°  L " + root.w.days[0].min + "°" : ""
            color: Theme.dim
            font { family: Theme.font; pixelSize: 11 }
        }
        Item { width: 1; height: 6 }
        Row {
            visible: root.w !== null
            width: parent.width
            Repeater {
                model: root.w ? root.w.days : []
                Column {
                    required property var modelData
                    width: col.width / 3
                    spacing: 4
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd").toUpperCase()
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 * Theme.ls }
                    }
                    WeatherIcon { anchors.horizontalCenter: parent.horizontalCenter; size: 26; kind: Sys.weatherKind(modelData.code) }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.max + "° / " + modelData.min + "°"
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
