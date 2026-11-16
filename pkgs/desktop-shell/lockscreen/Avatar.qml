import QtQuick
import QtQuick.Effects

// ~/.face in a rounded square; a plain person shape until it loads.
Item {
    id: root
    property int size: 140
    implicitWidth: size
    implicitHeight: size

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: root.size * 0.3
        color: Theme.cardHigh
        border.width: 1
        border.color: Theme.overlay(0.08)
        visible: face.status !== Image.Ready
        // fallback: head and shoulders
        Rectangle { x: parent.width / 2 - width / 2; y: parent.height * 0.24; width: parent.width * 0.26; height: width; radius: width / 2; color: Theme.dim }
        Rectangle { x: parent.width / 2 - width / 2; y: parent.height * 0.56; width: parent.width * 0.5; height: parent.height * 0.3; radius: width / 2; color: Theme.dim }
    }
    Image {
        id: face
        anchors.fill: parent
        source: Sys.hasFace ? "file://" + Sys.home + "/.face" : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: root.size * 0.3; color: "black" }
    }
}
