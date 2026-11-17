import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../motion"

// Clipboard history (cliphist) as a centered overlay on the focused monitor.
//  - search (fuzzy; images match their "png 800x600" description) and a type
//    filter: All / Text / Images / Pinned (Tab cycles it)
//  - keys: Up/Down, Ctrl+J/K, PageUp/PageDown move; Enter copies; Shift+Enter
//    copies and pastes into the window you came from; Ctrl+P pins or unpins;
//    Delete removes; Esc closes
//  - rows show what an entry is (colour swatch, link, code, image size) and
//    long text can be expanded in place
// A layer window with exclusive keyboard focus, so typing always works.
//
// Privacy: pins hold clipboard text, so they live in the private state dir
// (mode 0600); image thumbnails and expanded text are decoded into the
// runtime dir / memory only and removed when the panel closes. Entries a
// password manager marks sensitive never reach cliphist (wl-paste --watch
// sets CLIPBOARD_STATE=sensitive and cliphist >= 0.6 skips them).
Scope {
    id: root
    readonly property bool open: UiState.clipboardOpen
    property var entries: []        // [{ raw, id, preview, image, ext }]
    property var pins: []           // [{ text }]
    property int current: 0
    property string query: ""
    property string filter: "all"   // all | text | image | pinned
    property var expanded: ({})     // item key -> true
    property bool wipeArmed: false
    // true after a key moved the selection: hover is ignored until the mouse really moves
    property bool keyNav: false
    property var targetScreen: Quickshell.screens[0]

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/my-shell/clipboard-pins.json"
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/my-shell/clip"
    readonly property var filters: [
        { label: "All", value: "all" }, { label: "Text", value: "text" },
        { label: "Images", value: "image" }, { label: "Pinned", value: "pinned" }
    ]

    // ---- search ---------------------------------------------------------------------------
    // substring beats subsequence; -1 = no match
    function score(text, q) {
        const t = text.toLowerCase()
        const i = t.indexOf(q)
        if (i >= 0) return 1000 - i
        let from = 0, last = -1, gaps = 0
        for (const c of q) {
            const j = t.indexOf(c, from)
            if (j < 0) return -1
            if (last >= 0) gaps += j - last - 1
            last = j
            from = j + 1
        }
        return Math.max(1, 500 - gaps)
    }

    // one flat list for keyboard navigation: pins first, then history
    readonly property var flat: {
        const q = query.trim().toLowerCase()
        const out = []
        if (filter !== "image") {
            for (const p of pins) {
                const sc = q ? score(p.text, q) : 0
                if (sc >= 0) out.push({ kind: "pin", key: "p:" + p.text, pin: p, sc: sc })
            }
        }
        if (filter !== "pinned") {
            for (const e of entries) {
                if (filter === "text" && e.image) continue
                if (filter === "image" && !e.image) continue
                const sc = q ? score(e.preview, q) : 0
                if (sc >= 0) out.push({ kind: "entry", key: "e:" + e.id, entry: e, sc: sc })
            }
        }
        if (q) out.sort((a, b) => b.sc - a.sc)
        return out
    }

    function parse(text) {
        return text.split("\n").filter(l => l).slice(0, 200).map(l => {
            const tab = l.indexOf("\t")
            const id = tab < 0 ? l : l.slice(0, tab)
            const preview = tab < 0 ? l : l.slice(tab + 1)
            const m = /^\[\[ binary data .* (png|jpe?g|bmp|gif|webp)\b/i.exec(preview)
            return { raw: l, id: id, preview: preview, image: !!m, ext: m ? m[1].toLowerCase() : "" }
        })
    }
    // what a text entry is, for its badge
    function classify(text) {
        const s = text.trim()
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s)) return "color"
        if (/^https?:\/\/\S+$/i.test(s)) return "url"
        if (/[{};]\s*$|=>|^\s*(def|fn|func|function|const|let|var|import|from|class|#include|using|package|return)\b|<\/?[a-z][a-z0-9]*[ >]/m.test(s)) return "code"
        return "text"
    }
    // CSS #rrggbbaa -> Qt #aarrggbb
    function qtColor(s) {
        const t = s.trim()
        return t.length === 9 ? "#" + t.slice(7, 9) + t.slice(1, 7) : t
    }
    function imageInfo(preview) {
        const m = /binary data (\S+ \S+) (\w+) (\d+)x(\d+)/.exec(preview)
        return m ? m[2].toUpperCase() + "  ·  " + m[3] + "×" + m[4] + "  ·  " + m[1] : "Image"
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
    Process { id: pasteProc }
    Process { id: delProc; onExited: list.running = true }
    Process { id: wipeProc; onExited: list.running = true }
    Process {
        id: pinProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || root.pins.some(p => p.text === text) || root.pins.length >= 30) return
                root.pins = [{ text: text.slice(0, 10000) }].concat(root.pins)
                root.savePins()
            }
        }
    }
    // Shift+Enter: after the overlay has handed focus back, send Ctrl+V.
    // Needs wtype; without it this is just a copy.
    function pasteSoon() {
        pasteProc.exec(["bash", "-c", 'command -v wtype >/dev/null && { sleep 0.25; wtype -M ctrl v -m ctrl; }'])
    }
    function copyEntry(e) {
        // id is numeric; passed as an argument, never interpolated
        copyProc.exec(["bash", "-c", 'cliphist decode "$1" | wl-copy', "_", e.id])
    }
    function copyPin(p) { copyProc.exec(["bash", "-c", 'printf %s "$1" | wl-copy', "_", p.text]) }
    function remove(e) { delProc.exec(["bash", "-c", 'printf "%s\\n" "$1" | cliphist delete', "_", e.raw]) }
    function pin(e) { pinProc.exec(["bash", "-c", 'cliphist decode "$1"', "_", e.id]) }
    function unpin(p) { pins = pins.filter(x => x !== p); savePins() }
    function activate(item, paste) {
        if (!item) return
        item.kind === "pin" ? copyPin(item.pin) : copyEntry(item.entry)
        close()
        if (paste) pasteSoon()
    }
    function togglePin(item) {
        if (!item) return
        if (item.kind === "pin") unpin(item.pin)
        else if (!item.entry.image) pin(item.entry)
    }
    function toggleExpanded(key) {
        const c = Object.assign({}, expanded)
        if (c[key]) delete c[key]; else c[key] = true
        expanded = c
    }
    function move(delta) {
        if (flat.length === 0) return
        keyNav = true
        current = Math.max(0, Math.min(flat.length - 1, current + delta))
        view.positionViewAtIndex(current, ListView.Contain)
    }
    function cycleFilter(dir) {
        keyNav = true
        const i = filters.findIndex(f => f.value === filter)
        filter = filters[(i + dir + filters.length) % filters.length].value
        current = 0
    }
    function close() { UiState.clipboardOpen = false }

    Timer { id: unarm; interval: 4000; onTriggered: root.wipeArmed = false }

    onOpenChanged: {
        if (open) {
            const mon = Hyprland.focusedMonitor
            targetScreen = (mon && Quickshell.screens.find(s => s.name === mon.name)) || Quickshell.screens[0]
            query = ""; search.text = ""; current = 0; filter = "all"; expanded = ({}); wipeArmed = false; keyNav = false
            list.running = true
        } else {
            cleanup.exec(["bash", "-c", 'rm -rf "$1"', "_", cacheDir])   // thumbnails of what was copied
        }
    }
    Process { id: cleanup }

    PanelWindow {
        id: win
        screen: root.targetScreen
        // stays mapped (but click-through, unfocused) while the card fades out
        visible: root.open || card.opacity > 0.01
        mask: root.open ? null : closedMask
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clipboard"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        Region { id: closedMask }

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 580; height: Math.min(parent.height - 120, 660)
            radius: 18
            color: Theme.barBg
            border.color: Theme.border
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.94
            Behavior on opacity { Anim { kind: "effects" } }
            Behavior on scale { Anim { kind: "emphasized" } }
            MouseArea { anchors.fill: parent } // swallow clicks on the card

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                RowLayout {
                    spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 44; radius: 22; color: Theme.field
                        TextInput {
                            id: search
                            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg; font.pixelSize: 15
                            focus: root.open
                            onTextChanged: { root.query = text; root.current = 0 }
                            Keys.onEscapePressed: root.close()
                            Keys.onDownPressed: root.move(1)
                            Keys.onUpPressed: root.move(-1)
                            Keys.onReturnPressed: root.activate(root.flat[root.current], false)
                            Keys.onDeletePressed: { const it = root.flat[root.current]; if (it) it.kind === "pin" ? root.unpin(it.pin) : root.remove(it.entry) }
                            Keys.onPressed: event => {
                                const ctrl = event.modifiers & Qt.ControlModifier
                                const shift = event.modifiers & Qt.ShiftModifier
                                if (event.key === Qt.Key_Tab) root.cycleFilter(1)
                                else if (event.key === Qt.Key_Backtab) root.cycleFilter(-1)
                                else if (ctrl && event.key === Qt.Key_P) root.togglePin(root.flat[root.current])
                                else if (ctrl && event.key === Qt.Key_J) root.move(1)
                                else if (ctrl && event.key === Qt.Key_K) root.move(-1)
                                else if (event.key === Qt.Key_PageDown) root.move(6)
                                else if (event.key === Qt.Key_PageUp) root.move(-6)
                                else if (shift && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) root.activate(root.flat[root.current], true)
                                else return
                                event.accepted = true
                            }
                        }
                        Text {
                            anchors { fill: search }
                            verticalAlignment: Text.AlignVCenter
                            text: "Search clipboard…"; color: Theme.faint; font: search.font
                            opacity: search.text ? 0 : 1
                            Behavior on opacity { Anim { kind: "fastEffects" } }
                        }
                    }
                    // a destructive action: the first click arms it, the second runs it
                    Chip {
                        label: root.wipeArmed ? "Confirm?" : "Clear all"
                        destructive: true
                        confirm: root.wipeArmed
                        onClicked: {
                            if (!root.wipeArmed) { root.wipeArmed = true; unarm.restart(); return }
                            root.wipeArmed = false
                            wipeProc.exec(["cliphist", "wipe"])
                        }
                    }
                }

                Segmented {
                    Layout.fillWidth: true
                    columns: 4
                    cellHeight: 30
                    options: root.filters
                    current: root.filter
                    onPicked: v => { root.filter = v; root.current = 0 }
                }

                // The pointer tracker must sit outside the ListView: a handler declared
                // inside a Flickable lands in its scrolling content item, where
                // positions and hover shift with the scroll.
                Item {
                    id: listBox
                    Layout.fillWidth: true; Layout.fillHeight: true
                ListView {
                    id: view
                    anchors { fill: parent; rightMargin: 12 }   // room for the scroll bar
                    clip: true; spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel { values: root.flat; objectProp: "key" }
                    // set imperatively: a binding here loops with the hover sync
                    Connections { target: root; function onCurrentChanged() { view.currentIndex = root.current } }

                    add: Transition {
                        ParallelAnimation {
                            Anim { property: "opacity"; from: 0; to: 1; kind: "effects" }
                            Anim { property: "scale"; from: 0.94; to: 1; kind: "emphasized" }
                        }
                    }
                    remove: Transition {
                        ParallelAnimation {
                            Anim { property: "opacity"; to: 0; kind: "fastEffects" }
                            Anim { property: "scale"; to: 0.92; kind: "fastEffects" }
                        }
                    }
                    displaced: Transition { Anim { property: "y"; kind: "emphasized" } }

                    // The selection follows the row under the pointer, also
                    // when the list scrolls under a still pointer (the wheel),
                    // but not while keys are driving it.
                    property bool scrolling: false
                    Timer { id: settle; interval: 150; onTriggered: view.scrolling = false }
                    function syncHover() {
                        if (!ptr.hovered || root.keyNav) return
                        const i = view.indexAt(ptr.point.position.x, ptr.point.position.y + view.contentY)
                        if (i >= 0) root.current = i
                    }
                    onContentYChanged: { scrolling = true; settle.restart(); syncHover() }
                    HoverHandler {
                        id: ptr
                        onPointChanged: { root.keyNav = false; view.syncHover() }
                    }

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isPin: modelData.kind === "pin"
                        readonly property var e: modelData.entry
                        readonly property bool isImage: !isPin && e.image
                        readonly property string text: isPin ? modelData.pin.text : (isImage ? "" : e.preview)
                        readonly property string type: isImage ? "image" : root.classify(text)
                        readonly property bool canExpand: !isImage && (text.length > 78 || text.indexOf("\n") >= 0)
                        readonly property bool open: !!root.expanded[modelData.key]
                        // entries show a 100-char preview; expanding decodes the rest
                        property string full: isPin ? text : ""
                        readonly property real bodyHeight: open ? Math.min(fullText.implicitHeight, 200) : 0

                        width: ListView.view.width
                        height: (isImage ? 88 : 44) + bodyHeight + (open ? 12 : 0)
                        radius: 12
                        // the selection is drawn on the row itself, so it can never
                        // drift away from it while the list scrolls
                        readonly property bool selected: index === root.current
                        color: selected ? Theme.accentSoft : hov.containsMouse ? Theme.surfaceHover : Theme.surface
                        border.width: selected ? 1 : 0
                        border.color: Theme.accent
                        clip: true
                        Behavior on height { Anim { kind: "emphasized" } }
                        Behavior on color { CAnim { kind: "fastEffects" } }

                        Ripple { id: rip; radius: row.radius }

                        // full text of an expanded entry
                        Process {
                            id: fullProc
                            running: row.open && !row.isPin && !row.isImage && row.full === ""
                            command: ["cliphist", "decode", row.isPin || row.isImage ? "0" : row.e.id]
                            stdout: StdioCollector { onStreamFinished: row.full = text.slice(0, 4000) }
                        }
                        // thumbnail for images (decoded lazily into tmpfs)
                        Process {
                            id: thumb
                            property bool ready: false
                            running: row.isImage
                            onExited: code => ready = code === 0
                            command: ["bash", "-c", 'mkdir -p "$1" && [ -f "$2" ] || cliphist decode "$3" > "$2"', "_", root.cacheDir, root.cacheDir + "/" + row.e.id + "." + row.e.ext, row.e.id]
                        }

                        // leading marker: colour swatch / pin star
                        Item {
                            id: lead
                            visible: !row.isImage && (row.type === "color" || row.isPin)
                            anchors { left: parent.left; leftMargin: 14; top: parent.top; topMargin: 11 }
                            width: visible ? 22 : 0; height: 22
                            Rectangle {
                                visible: row.type === "color"
                                anchors.fill: parent; radius: 6
                                color: row.type === "color" ? root.qtColor(row.text) : "transparent"
                                border.width: 1; border.color: Theme.border
                            }
                            Text { visible: row.type !== "color"; anchors.centerIn: parent; text: "★"; color: Theme.accent; font.pixelSize: 15 }
                        }

                        Image {
                            visible: thumb.ready
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 96; height: 68; fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false
                            sourceSize.height: 136
                            source: thumb.ready ? "file://" + root.cacheDir + "/" + row.e.id + "." + row.e.ext : ""
                        }
                        Text {
                            visible: row.isImage
                            anchors { left: parent.left; leftMargin: 124; verticalCenter: parent.verticalCenter }
                            text: row.isImage ? root.imageInfo(row.e.preview) : ""
                            color: Theme.muted; font.pixelSize: 12
                        }

                        // one-line preview
                        Text {
                            visible: !row.isImage
                            opacity: row.open ? 0 : 1
                            Behavior on opacity { Anim { kind: "fastEffects" } }
                            anchors { left: parent.left; leftMargin: lead.visible ? 44 : 18; right: tag.left; rightMargin: 8; top: parent.top; topMargin: 0 }
                            height: 44
                            verticalAlignment: Text.AlignVCenter
                            text: row.text.replace(/\s+/g, " ")
                            elide: Text.ElideRight; color: Theme.fg
                            font { pixelSize: Theme.fontSize; family: row.type === "code" ? "monospace" : Qt.application.font.family }
                        }
                        // expanded text
                        Text {
                            id: fullText
                            visible: !row.isImage
                            opacity: row.open ? 1 : 0
                            Behavior on opacity { Anim { kind: "effects" } }
                            anchors { left: parent.left; leftMargin: lead.visible ? 44 : 18; right: parent.right; rightMargin: 18; top: parent.top; topMargin: 44 }
                            width: parent.width - 62
                            height: row.bodyHeight
                            clip: true
                            wrapMode: Text.Wrap
                            text: row.full || row.text
                            color: Theme.fg
                            font { pixelSize: Theme.fontSize - 1; family: row.type === "code" ? "monospace" : Qt.application.font.family }
                        }

                        // kind tag for links and code
                        Rectangle {
                            id: tag
                            visible: row.type === "url" || row.type === "code"
                            anchors { right: actions.left; rightMargin: 8; top: parent.top; topMargin: 13 }
                            width: visible ? tagText.implicitWidth + 12 : 0; height: 18; radius: 9
                            color: Theme.card
                            Text { id: tagText; anchors.centerIn: parent; text: row.type === "url" ? "LINK" : "CODE"; color: Theme.muted; font { pixelSize: 9; bold: true } }
                        }

                        MouseArea {
                            id: hov
                            anchors { left: parent.left; right: parent.right; top: parent.top; rightMargin: 112 }
                            height: row.isImage ? 88 : 44
                            hoverEnabled: true
                            onPressed: mouse => rip.press(mouse.x, mouse.y)
                            onPressedChanged: rip.pressed = pressed
                            onClicked: root.activate(row.modelData, false)
                        }
                        Row {
                            id: actions
                            anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: row.isImage ? 30 : 8 }
                            spacing: 4
                            opacity: hov.containsMouse || actionsHover.hovered || row.index === root.current ? 1 : 0.35
                            Behavior on opacity { Anim { kind: "fastEffects" } }
                            HoverHandler { id: actionsHover }
                            RowBtn {
                                visible: row.canExpand
                                glyph: "⌄"
                                rotation: row.open ? 180 : 0
                                Behavior on rotation { Anim { kind: "emphasized" } }
                                onClicked: root.toggleExpanded(row.modelData.key)
                            }
                            RowBtn {
                                visible: !row.isImage
                                glyph: row.isPin ? "★" : "☆"
                                onClicked: row.isPin ? root.unpin(row.modelData.pin) : root.pin(row.e)
                            }
                            RowBtn {
                                glyph: "✕"; glyphSize: 12
                                onClicked: row.isPin ? root.unpin(row.modelData.pin) : root.remove(row.e)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.query ? "No matches" : root.filter === "pinned" ? "Nothing pinned" : root.filter === "image" ? "No images" : "Empty"
                        color: Theme.muted; font.pixelSize: 14
                        opacity: root.flat.length === 0 ? 1 : 0
                        Behavior on opacity { Anim { kind: "slowEffects" } }
                    }
                }

                // Scroll position: a thin thumb on the right. It shows while the
                // list moves or the pointer is near it, and can be dragged.
                Item {
                    id: bar
                    visible: view.contentHeight > view.height + 1
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 10
                    opacity: view.scrolling || barMouse.containsMouse || barMouse.pressed ? 1 : 0.4
                    Behavior on opacity { Anim { kind: "effects" } }

                    Rectangle {
                        id: thumb
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: barMouse.containsMouse || barMouse.pressed ? 8 : 4
                        Behavior on width { Anim { kind: "fastSpatial" } }
                        radius: width / 2
                        color: barMouse.pressed ? Theme.accent : Theme.muted
                        Behavior on color { CAnim { kind: "fastEffects" } }
                        height: Math.max(28, view.visibleArea.heightRatio * bar.height)
                        y: Math.max(0, Math.min(bar.height - height, view.visibleArea.yPosition * bar.height))
                    }
                    MouseArea {
                        id: barMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        function seek(my) {
                            const travel = bar.height - thumb.height
                            if (travel <= 0) return
                            const f = Math.max(0, Math.min(1, (my - thumb.height / 2) / travel))
                            view.contentY = view.originY + f * (view.contentHeight - view.height)
                        }
                        // the list moves under a still pointer: do not let hover steal the selection
                        onPressed: mouse => { root.keyNav = true; seek(mouse.y) }
                        onPositionChanged: mouse => { if (pressed) seek(mouse.y) }
                    }
                }
                }
                Text { Layout.topMargin: 2; text: "Enter copy · ⇧Enter paste · Tab filter · Ctrl+P pin · Del remove · Esc close"; color: Theme.faint; font.pixelSize: 11 }
            }
        }
    }
}
