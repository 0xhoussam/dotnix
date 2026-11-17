import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import "."

// Secure lock screen on ext-session-lock-v1: the compositor keeps every
// output locked until we unlock after a successful PAM conversation, or
// shows its own failsafe if this process dies.
//
// LOCK_PREVIEW=1 renders the same surfaces as plain overlay windows without
// locking anything (Ctrl+Escape quits), for working on the design.
ShellRoot {
    Loader {
        active: !Session.preview && !Session.greeter
        sourceComponent: Scope {
            WlSessionLock {
                id: lock
                locked: true
                // Quit only once the unlock request has gone out; quitting
                // earlier makes the compositor report "lockscreen died".
                onLockedChanged: if (!locked) Qt.callLater(Qt.quit)
                WlSessionLockSurface {
                    color: Theme.bg
                    LockSurface { anchors.fill: parent }
                }
            }
            Connections { target: Session; function onUnlockRequested() { lock.locked = false } }
            // The compositor refused (another locker running): exit non-zero
            // so the caller can retry.
            Timer {
                interval: 5000; running: true
                onTriggered: if (!lock.secure) { console.error("lock: compositor did not confirm the lock"); Qt.exit(1) }
            }
        }
    }

    // Login screen: a plain fullscreen window (cage, no layer-shell), the same
    // surface and intro; the outro ends by starting the session.
    Loader {
        active: Session.greeter
        sourceComponent: FloatingWindow {
            color: Theme.bg
            visible: true
            LockSurface { anchors.fill: parent }
            Connections {
                target: Session
                function onUnlockRequested() { Greetd.launch(Session.sessionCmd, [], true) }
            }
        }
    }

    Loader {
        active: Session.preview
        sourceComponent: Variants {
            model: Quickshell.screens
            PanelWindow {
                required property var modelData
                screen: modelData
                color: Theme.bg
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "lock-preview"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                anchors { top: true; bottom: true; left: true; right: true }
                LockSurface { id: surface; anchors.fill: parent }
                // LOCK_SNAPSHOT=/path/file.png saves the first screen's surface
                // after the intro and quits (for checking the design headlessly).
                Timer {
                    interval: Number(Quickshell.env("LOCK_SNAPSHOT_MS") || 3600); running: Quickshell.env("LOCK_SNAPSHOT") !== "" && modelData === Quickshell.screens[0]
                    onTriggered: surface.grabToImage(r => { r.saveToFile(Quickshell.env("LOCK_SNAPSHOT")); Qt.quit() })
                }
                Shortcut { sequence: "Ctrl+Escape"; onActivated: Qt.quit() }
                Connections { target: Session; function onUnlockRequested() { Qt.quit() } }
            }
        }
    }
}
