import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

// Secure lock screen on ext-session-lock-v1: the compositor keeps every
// output locked until we unlock after a successful PAM conversation, or
// shows its own failsafe if this process dies.
//
// LOCK_PREVIEW=1 renders the same surfaces as plain overlay windows without
// locking anything (Ctrl+Escape quits), for working on the design.
ShellRoot {
    Loader {
        active: !Session.preview
        sourceComponent: Scope {
            WlSessionLock {
                id: lock
                locked: true
                // Quit only once the unlock request has gone out; quitting
                // earlier makes the compositor report "lockscreen died".
                onLockedChanged: if (!locked) Qt.callLater(Qt.quit)
                WlSessionLockSurface {
                    color: "#0b0d12"
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

    Loader {
        active: Session.preview
        sourceComponent: Variants {
            model: Quickshell.screens
            PanelWindow {
                required property var modelData
                screen: modelData
                color: "#0b0d12"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "lock-preview"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                anchors { top: true; bottom: true; left: true; right: true }
                LockSurface { anchors.fill: parent }
                Shortcut { sequence: "Ctrl+Escape"; onActivated: Qt.quit() }
                Connections { target: Session; function onUnlockRequested() { Qt.quit() } }
            }
        }
    }
}
