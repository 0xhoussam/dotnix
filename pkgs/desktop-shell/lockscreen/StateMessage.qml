import QtQuick

// One status line under the password pill. A new message scales and fades
// in; errors flash twice; it eases away when there is nothing to say.
Item {
    id: root
    property string text: ""
    property bool error: false
    implicitHeight: Math.max(18, label.implicitHeight)
    Behavior on implicitHeight { Anim { } }

    // keep showing the last message while it fades out
    property string shownText: ""
    onTextChanged: if (text) shownText = text

    Text {
        id: label
        anchors { left: parent.left; right: parent.right }
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.shownText.toUpperCase()
        color: root.error ? Theme.error : Theme.dim
        opacity: root.text ? 1 : 0
        scale: root.text ? 1 : 0.8
        Behavior on opacity { Anim { kind: "effects" } }
        Behavior on scale { Anim { kind: "fastSpatial" } }
        Behavior on color { CAnim { kind: "fastEffects" } }
        font { family: Theme.font; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 * Theme.ls }
        SequentialAnimation {
            id: flash
            loops: 2
            Anim { target: label; property: "opacity"; to: 0.3; duration: 120; kind: "standard" }
            Anim { target: label; property: "opacity"; to: 1; duration: 120; kind: "standard" }
        }
    }
    onErrorChanged: if (error && text) flash.restart()
    onShownTextChanged: if (error && text) flash.restart()
}
