import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "items"

// Port of bar/app.tsx. The window keeps the full bar height while hidden
// (resizing a layer surface on the fly is unreliable); hiding only slides
// the body out and shrinks the input mask to the edge strip.
PanelWindow {
    id: win

    readonly property bool bottom: Config.position === "bottom"
    readonly property bool autohide: Config.autohideEnabled
    // Starts shown (a surface first mapped collapsed gets a bogus size from
    // Hyprland); the hide countdown starts once mapped.
    property bool shown: true

    color: "transparent"
    implicitHeight: Config.size
    exclusionMode: autohide ? ExclusionMode.Ignore : ExclusionMode.Auto
    WlrLayershell.namespace: "bar"
    anchors {
        top: !bottom
        bottom: bottom
        left: true
        right: true
    }

    // Hidden: only a `revealZone` strip at the edge takes input; the rest
    // of the transparent window is click-through. Shown: the whole bar.
    mask: Region {
        x: 0
        y: win.autohide && !win.shown && win.bottom ? Config.size - Config.revealZone : 0
        width: win.width
        height: win.autohide && !win.shown ? Config.revealZone : Config.size
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) win.reveal()
    }

    // Poll rather than track leave events: popups live on their own surfaces.
    property int idleMs: 0
    Timer {
        id: hideTimer
        interval: 150
        repeat: true
        running: false
        onTriggered: {
            const held = hover.hovered || UiState.panelOpen || UiState.openPopups > 0
            win.idleMs = held ? 0 : win.idleMs + interval
            if (win.idleMs >= Config.hideDelay) {
                running = false
                win.shown = false
            }
        }
    }

    function reveal() {
        if (!autohide) return
        shown = true
        idleMs = 0
        hideTimer.running = true
    }

    Component.onCompleted: reveal() // initial peek
    Connections {
        target: UiState
        function onPanelOpenChanged() { if (UiState.panelOpen) win.reveal() }
    }

    Rectangle {
        id: body
        width: parent.width
        height: Config.size
        y: win.shown ? 0 : (win.bottom ? Config.size : -Config.size)
        color: Theme.barBg
        Behavior on y { NumberAnimation { duration: Config.transition; easing.type: Easing.OutCubic } }

        // Module registry: name -> component.
        readonly property var registry: ({
            logo: logoC, workspaces: workspacesC, clock: clockC, keyboard: keyboardC,
            network: placeholderC, bluetooth: placeholderC, volume: volumeC,
            battery: batteryC, clipboard: clipboardC, settings: settingsC, systray: systrayC
        })

        Component { id: logoC; Logo {} }
        Component { id: workspacesC; Workspaces {} }
        Component { id: clockC; Clock {} }
        Component { id: keyboardC; Keyboard {} }
        Component { id: volumeC; Volume {} }
        Component { id: batteryC; Battery {} }
        Component { id: clipboardC; Clipboard {} }
        Component { id: settingsC; Settings {} }
        Component { id: systrayC; Systray {} }
        Component { id: placeholderC; Item {} } // network / bluetooth: phases 5-6

        component Section: Row {
            id: sec
            property var names: []
            spacing: Config.spacing
            Repeater {
                model: sec.names
                Loader {
                    required property string modelData
                    sourceComponent: body.registry[modelData]
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    onStatusChanged: if (status === Loader.Null) console.error("Bar: unknown module '" + modelData + "'")
                }
            }
        }

        Section {
            names: Config.modulesStart
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        }
        Section {
            names: Config.modulesCenter
            anchors.centerIn: parent
        }
        Section {
            names: Config.modulesEnd
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        }
    }
}
