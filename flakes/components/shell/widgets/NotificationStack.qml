import QtQuick
import ".."

// A notification card with the other notifications of the same app stacked
// behind it (up to two visible edges). Clicking "+N more" emits moreClicked.
Item {
    id: root
    required property var n
    property int extra: 0
    property bool toast: false
    signal moreClicked()

    readonly property int layers: Math.min(extra, 2)
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight + layers * 5
    width: implicitWidth
    height: implicitHeight

    Repeater {
        model: root.layers
        Rectangle {
            required property int index
            // deepest layer first so nearer ones draw on top
            z: -1 - index
            x: 6 * (index + 1)
            y: 5 * (index + 1)
            width: card.width - 12 * (index + 1)
            height: card.height
            radius: 12
            color: root.toast ? Qt.lighter(Theme.popoverBg, 1.22 - 0.07 * index) : Theme.stackLayer
            border.width: 1
            border.color: Theme.border
        }
    }

    // Clicking anywhere on the folded card (outside its own buttons) expands it.
    MouseArea {
        anchors.fill: card
        z: -0.5            // above the stacked layers, below the card's own controls
        enabled: root.extra > 0
        cursorShape: root.extra > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.moreClicked()
    }

    NotificationCard {
        id: card
        n: root.n
        toast: root.toast
        extra: root.extra
        onMoreClicked: root.moreClicked()
    }
}
