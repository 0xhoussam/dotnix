import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

// Clipboard history (cliphist) as a centered overlay: search, keyboard
// navigation (Up/Down, Enter copies, Delete removes, Esc closes), image
// thumbnails, per-entry delete and pinned text snippets. A layer window with
// exclusive keyboard focus, so typing always works.
//
// Privacy: pins hold clipboard text, so they live in the private state dir
// (mode 0600); image thumbnails are decoded into the runtime dir (tmpfs) and
// removed when the panel closes.
Scope {
    id: root
    readonly property bool open: UiState.clipboardOpen
    property var entries: []        // [{ raw, id, preview, image, ext }]
    property var pins: []           // [{ text }]
    property int current: 0
    property string query: ""

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/my-shell/clipboard-pins.json"
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/my-shell/clip"

    readonly property var shownPins: pins.filter(p => !query || p.text.toLowerCase().includes(query.toLowerCase()))
    readonly property var shownEntries: entries.filter(e => !query || (!e.image && e.preview.toLowerCase().includes(query.toLowerCase())))
    // one flat list for keyboard navigation: pins first, then history
    readonly property var flat: shownPins.map(p => ({ kind: "pin", pin: p })).concat(shownEntries.map(e => ({ kind: "entry", entry: e })))

    function parse(text) {
        return text.split("\n").filter(l => l).slice(0, 200).map(l => {
            const tab = l.indexOf("\t")
            const id = tab < 0 ? l : l.slice(0, tab)
            const preview = tab < 0 ? l : l.slice(tab + 1)
            const m = /^\[\[ binary data .* (png|jpe?g|bmp|gif|webp)\b/i.exec(preview)
            return { raw: l, id: id, preview: preview, image: !!m, ext: m ? m[1].toLowerCase() : "" }
        })
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.entries = root.parse(text) }
    }
    FileView {
        id: pinFile
        path: root.stateFile
        blockLoading: true
        onLoaded: { try { root.pins = JSON.parse(text()) } catch (e) { } }
    }
    Process { id: writer }
    function savePins() {
        writer.exec(["bash", "-c", 'umask 077; mkdir -p "$(dirname "$1")"; printf %s "$2" > "$1.tmp" && mv "$1.tmp" "$1"', "_", stateFile, JSON.stringify(pins)])
    }

    // ---- actions ----
    Process { id: copyProc }
    Process { id: delProc; onExited: list.running = true }
    Process { id: wipeProc; onExited: list.running = true }
    Process {
        id: pinProc
        property string raw
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || root.pins.some(p => p.text === text) || root.pins.length >= 30) return
                root.pins = [{ text: text.slice(0, 10000) }].concat(root.pins)
                root.savePins()
            }
        }
    }
    function copyEntry(e) {
        // id is numeric; passed as an argument, never interpolated
        copyProc.exec(["bash", "-c", 'cliphist decode "$1" | wl-copy', "_", e.id])
        close()
    }
    function copyPin(p) { copyProc.exec(["bash", "-c", 'printf %s "$1" | wl-copy', "_", p.text]); close() }
    function remove(e) { delProc.exec(["bash", "-c", 'printf "%s\\n" "$1" | cliphist delete', "_", e.raw]) }
    function pin(e) { pinProc.exec(["bash", "-c", 'cliphist decode "$1"', "_", e.id]) }
    function unpin(p) { pins = pins.filter(x => x !== p); savePins() }
    function activate(item) { if (!item) return; item.kind === "pin" ? copyPin(item.pin) : copyEntry(item.entry) }
    function close() { UiState.clipboardOpen = false }

    onOpenChanged: {
        if (open) { query = ""; search.text = ""; current = 0; list.running = true }
        else cleanup.exec(["bash", "-c", 'rm -rf "$1"', "_", cacheDir])   // thumbnails of what was copied
    }
    Process { id: cleanup }

    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clipboard"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 560; height: Math.min(parent.height - 120, 620)
            radius: 18
            color: Theme.popoverBg
            border.color: Theme.border
            MouseArea { anchors.fill: parent } // swallow clicks on the card

            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 10

                RowLayout {
                    spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 40; radius: 20; color: Theme.field
                        TextInput {
                            id: search
                            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg; font.pixelSize: 15
                            focus: root.open
                            onTextChanged: { root.query = text; root.current = 0 }
                            Keys.onEscapePressed: root.close()
                            Keys.onDownPressed: root.current = Math.min(root.current + 1, root.flat.length - 1)
                            Keys.onUpPressed: root.current = Math.max(root.current - 1, 0)
                            Keys.onReturnPressed: root.activate(root.flat[root.current])
                            Keys.onDeletePressed: { const it = root.flat[root.current]; if (it) it.kind === "pin" ? root.unpin(it.pin) : root.remove(it.entry) }
                            Text { visible: !search.text; text: "Search clipboard…"; color: Theme.faint; font: search.font }
                        }
                    }
                    Chip { label: "Clear all"; destructive: true; onClicked: wipeProc.exec(["cliphist", "wipe"]) }
                }

                ListView {
                    id: view
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.flat
                    currentIndex: root.current
                    highlightFollowsCurrentItem: true
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isPin: modelData.kind === "pin"
                        readonly property var e: modelData.entry
                        width: ListView.view.width
                        height: !isPin && e.image ? 96 : 40
                        radius: 12
                        color: index === root.current ? Theme.accentSoft : hov.containsMouse ? Theme.surfaceHover : Theme.surface
                        Behavior on color { ColorAnimation { duration: 90 } }

                        // thumbnail for images (decoded lazily into tmpfs)
                        Process {
                            id: thumb
                            running: !row.isPin && row.e.image
                            command: ["bash", "-c", 'mkdir -p "$1" && [ -f "$2" ] || cliphist decode "$3" > "$2"', "_", root.cacheDir, root.cacheDir + "/" + row.e.id + "." + row.e.ext, row.e.id]
                        }
                        Image {
                            visible: !row.isPin && row.e.image && thumb.running === false
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 100; height: 80; fillMode: Image.PreserveAspectFit; asynchronous: true
                            source: visible ? "file://" + root.cacheDir + "/" + row.e.id + "." + row.e.ext : ""
                        }
                        Text {
                            visible: row.isPin || !row.e.image
                            anchors { left: parent.left; leftMargin: 14; right: actions.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: (row.isPin ? "★  " : "") + (row.isPin ? row.modelData.pin.text : row.e.preview).replace(/\s+/g, " ")
                            elide: Text.ElideRight; color: Theme.fg; font.pixelSize: Theme.fontSize
                        }
                        Text {
                            visible: !row.isPin && row.e.image
                            anchors { left: parent.left; leftMargin: 120; verticalCenter: parent.verticalCenter }
                            text: "Image"; color: Theme.muted; font.pixelSize: 12
                        }
                        MouseArea { id: hov; anchors { fill: parent; rightMargin: 80 } hoverEnabled: true; onEntered: root.current = row.index; onClicked: root.activate(row.modelData) }
                        Row {
                            id: actions
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 4
                            opacity: hov.containsMouse || actionsHover.hovered || row.index === root.current ? 1 : 0.35
                            HoverHandler { id: actionsHover }
                            Rectangle {
                                visible: !row.isPin && !row.e.image
                                width: 28; height: 28; radius: 14; color: pm.containsMouse ? Theme.hover : "transparent"
                                Text { anchors.centerIn: parent; text: "☆"; color: Theme.muted; font.pixelSize: 15 }
                                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: root.pin(row.e) }
                            }
                            Rectangle {
                                width: 28; height: 28; radius: 14; color: dm.containsMouse ? Theme.hover : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; color: Theme.muted; font.pixelSize: 12 }
                                MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; onClicked: row.isPin ? root.unpin(row.modelData.pin) : root.remove(row.e) }
                            }
                        }
                    }
                    Text {
                        visible: root.flat.length === 0
                        anchors.centerIn: parent
                        text: root.query ? "No matches" : "Empty"
                        color: Theme.muted; font.pixelSize: 14
                    }
                }
                Text { text: "Enter copy · Delete remove · ☆ pin · Esc close"; color: Theme.faint; font.pixelSize: 11 }
            }
        }
    }
}
