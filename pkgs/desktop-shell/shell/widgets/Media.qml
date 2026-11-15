import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import ".."

// Now-playing card(s). Only shown when an MPRIS player exists.
Column {
    spacing: 8
    visible: Mpris.players.values.length > 0
    Repeater {
        model: Mpris.players
        Rectangle {
            id: card
            required property var modelData
            width: parent.width
            height: row.implicitHeight + 20
            radius: 12
            color: Theme.card

            RowLayout {
                id: row
                anchors { fill: parent; margins: 10 }
                spacing: 12
                Image {
                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                    sourceSize: Qt.size(112, 112)
                    fillMode: Image.PreserveAspectCrop
                    source: card.modelData.trackArtUrl || Quickshell.iconPath("audio-x-generic-symbolic", true)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.trackTitle || "Unknown"
                        elide: Text.ElideRight
                        color: Theme.fg; font.bold: true; font.pixelSize: Theme.fontSize
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !!card.modelData.trackArtist
                        text: card.modelData.trackArtist
                        elide: Text.ElideRight
                        color: Theme.muted; font.pixelSize: 12
                    }
                    Row {
                        Layout.topMargin: 8
                        spacing: 4
                        component Btn: Rectangle {
                            id: b
                            property string icon
                            property bool strong: false
                            signal clicked()
                            width: 24; height: 24; radius: 12
                            color: ma.containsMouse ? Theme.hover : (strong ? Theme.field : "transparent")
                            Image { layer.enabled: true; layer.effect: Tint {}
                                anchors.centerIn: parent
                                width: 16; height: 16
                                sourceSize: Qt.size(32, 32)
                                source: Quickshell.iconPath(b.icon, true)
                            }
                            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
                        }
                        Btn { visible: card.modelData.canGoPrevious; icon: "media-skip-backward-symbolic"; onClicked: card.modelData.previous() }
                        Btn { strong: true; icon: card.modelData.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; onClicked: card.modelData.togglePlaying() }
                        Btn { visible: card.modelData.canGoNext; icon: "media-skip-forward-symbolic"; onClicked: card.modelData.next() }
                    }
                }
            }
        }
    }
}
