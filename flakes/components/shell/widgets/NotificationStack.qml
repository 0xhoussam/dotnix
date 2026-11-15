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
    implicitHeight: card.implicitHeight + layers * 7
    width: implicitWidth
    height: implicitHeight

    Repeater {
        model: root.layers
        Rectangle {
            required property int index
            // deepest layer first so nearer ones draw on top
            z: -1 - index
            x: 8 * (index + 1)
            y: 7 * (index + 1)
            width: card.width - 16 * (index + 1)
            height: card.height
            radius: 12
            color: root.toast ? Qt.lighter(Theme.popoverBg, 1.22 - 0.07 * index) : Qt.rgba(1, 1, 1, 0.07 - 0.02 * index)
            border.width: 1
            border.color: Theme.border
        }
    }

    NotificationCard {
        id: card
        n: root.n
        toast: root.toast
        extra: root.extra
        onMoreClicked: root.moreClicked()
    }
}
