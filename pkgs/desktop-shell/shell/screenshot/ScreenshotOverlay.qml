import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../quick"
import "../widgets"

// Screenshot overlay. One layer window per screen shows a frozen copy of that
// screen (ScreencopyView) under a dim layer.
//  - region: drag to select; window: click the highlighted window; screen: the
//    whole screen is selected. The selection can be moved and resized (Move).
//  - tools: pen, arrow, box, oval, highlighter, text, numbered step, pixelate
//  - output: copy, save, OCR, or record the area (wf-recorder)
//  - keys: Enter copy, Ctrl+S save, Ctrl+Z / Ctrl+Shift+Z undo / redo,
//    V P A R O H T N B pick a tool, arrows nudge the selection, Esc cancels
// Everything that ends up in the image (frame, pixelation, annotations) lives
// in `scene`; the crop is a ShaderEffectSource of it, so the dim layer, the
// handles and the toolbar never reach the file.
Scope {
    id: root
    readonly property var svc: ScreenshotService

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.svc.active
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "screenshot"
            WlrLayershell.keyboardFocus: root.svc.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            readonly property real sw: modelData.width
            readonly property real sh: modelData.height
            readonly property real dpr: modelData.devicePixelRatio
            readonly property string mode: root.svc.mode

            // selection, in screen-local logical pixels
            property real selX: 0
            property real selY: 0
            property real selW: 0
            property real selH: 0
            property bool hasSel: false
            property string tool: "move"
            property string drag: ""            // "", new, draw, or a handle (m tl t tr r br b bl l)
            property var dragStart: null
            property var shapes: []
            property var redoStack: []
            property var draft: null
            property var textAt: null
            property color penColor: "#ff4d4d"
            property int penWidth: 4
            property var wins: []
            property var hover: null
            readonly property bool ready: frame.hasContent
            readonly property var blurs: (draft ? shapes.concat([draft]) : shapes).filter(s => s.type === "blur")
            readonly property var palette: ["#ff4d4d", "#ffcc00", "#35d07f", "#3584e4", "#ffffff", "#000000"]
            readonly property var tools: [
                { id: "move", label: "Move", key: "V" }, { id: "pen", label: "Pen", key: "P" },
                { id: "arrow", label: "Arrow", key: "A" }, { id: "rect", label: "Box", key: "R" },
                { id: "oval", label: "Oval", key: "O" }, { id: "highlight", label: "Mark", key: "H" },
                { id: "text", label: "Text", key: "T" }, { id: "step", label: "Step", key: "N" },
                { id: "blur", label: "Pixelate", key: "B" }
            ]

            // ---- lifecycle ------------------------------------------------------------------
            Connections {
                target: root.svc
                function onActiveChanged() { if (root.svc.active) win.reset() }
            }
            function reset() {
                shapes = []; redoStack = []; draft = null; textAt = null
                tool = "move"; drag = ""; dragStart = null
                keys.forceActiveFocus()
                applyMode()
            }
            function applyMode() {
                hasSel = false; hover = null; draft = null
                if (mode === "screen") {
                    selX = 0; selY = 0; selW = sw; selH = sh; hasSel = true
                } else if (mode === "window") {
                    wins = []
                    clients.running = true
                }
            }
            function setMode(m) {
                root.svc.mode = m
                shapes = []; redoStack = []
                tool = "move"
                applyMode()
            }

            // ---- windows (Hyprland) ---------------------------------------------------------
            Process {
                id: clients
                command: ["hyprctl", "clients", "-j"]
                stdout: StdioCollector { onStreamFinished: win.parseClients(text) }
            }
            function parseClients(text) {
                let list
                try { list = JSON.parse(text) } catch (e) { return }
                const mon = Hyprland.monitorFor(modelData)
                const ws = mon && mon.activeWorkspace ? mon.activeWorkspace.id : null
                list = list.filter(c => c.mapped && !c.hidden && (ws === null || c.workspace.id === ws))
                // floating windows sit above tiled ones; then most recently focused first
                list.sort((a, b) => (b.floating - a.floating) || (a.focusHistoryID - b.focusHistoryID))
                wins = list.map(c => ({ x: c.at[0] - modelData.x, y: c.at[1] - modelData.y, w: c.size[0], h: c.size[1], title: c.title }))
            }
            function windowAt(x, y) {
                return wins.find(w => x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h) || null
            }

            // ---- selection geometry ---------------------------------------------------------
            function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
            function setSel(x, y, w, h) {
                selX = x; selY = y; selW = w; selH = h
                hasSel = w > 2 && h > 2
            }
            function handleAt(x, y) {
                const t = 9
                const l = Math.abs(x - selX) < t, r = Math.abs(x - (selX + selW)) < t
                const tp = Math.abs(y - selY) < t, b = Math.abs(y - (selY + selH)) < t
                const inX = x > selX - t && x < selX + selW + t, inY = y > selY - t && y < selY + selH + t
                if (tp && l) return "tl"
                if (tp && r) return "tr"
                if (b && l) return "bl"
                if (b && r) return "br"
                if (tp && inX) return "t"
                if (b && inX) return "b"
                if (l && inY) return "l"
                if (r && inY) return "r"
                if (x > selX && x < selX + selW && y > selY && y < selY + selH) return "m"
                return ""
            }
            function cursorFor(h) {
                if (tool !== "move" && hasSel) return Qt.CrossCursor
                switch (h) {
                case "tl": case "br": return Qt.SizeFDiagCursor
                case "tr": case "bl": return Qt.SizeBDiagCursor
                case "t": case "b": return Qt.SizeVerCursor
                case "l": case "r": return Qt.SizeHorCursor
                case "m": return Qt.SizeAllCursor
                }
                return Qt.CrossCursor
            }

            // ---- pointer --------------------------------------------------------------------
            function press(x, y) {
                if (textAt) { commitText(); return }
                if (!ready) return
                const inSel = hasSel && x >= selX && x <= selX + selW && y >= selY && y <= selY + selH
                if (hasSel && tool !== "move") {
                    if (!inSel) return
                    if (tool === "text") { textAt = { x: x, y: y }; return }
                    if (tool === "step") {
                        addShape({ type: "step", x: x, y: y, n: shapes.filter(s => s.type === "step").length + 1, color: "" + penColor, w: penWidth })
                        return
                    }
                    draft = { type: tool, color: "" + penColor, w: penWidth, pts: [{ x: x, y: y }], x0: x, y0: y, x1: x, y1: y }
                    drag = "draw"
                    return
                }
                const h = hasSel ? handleAt(x, y) : ""
                if (h && mode !== "screen" || h === "m") {
                    drag = h
                    dragStart = { x: x, y: y, sx: selX, sy: selY, sw: selW, sh: selH }
                    return
                }
                if (mode === "window") {
                    if (!hasSel && hover) setSel(hover.x, hover.y, hover.w, hover.h)
                    return
                }
                if (mode === "region") {
                    shapes = []; redoStack = []
                    drag = "new"
                    dragStart = { x: x, y: y }
                    hasSel = false
                    selX = x; selY = y; selW = 0; selH = 0
                }
            }
            function move(x, y) {
                if (drag === "") {
                    if (mode === "window" && !hasSel) hover = windowAt(x, y)
                    return
                }
                const d = dragStart
                if (drag === "draw") {
                    const cx = clamp(x, selX, selX + selW), cy = clamp(y, selY, selY + selH)
                    const s = Object.assign({}, draft)
                    if (s.type === "pen" || s.type === "highlight") s.pts = s.pts.concat([{ x: cx, y: cy }])
                    s.x1 = cx; s.y1 = cy
                    draft = s
                } else if (drag === "new") {
                    const x0 = clamp(d.x, 0, sw), y0 = clamp(d.y, 0, sh)
                    const x1 = clamp(x, 0, sw), y1 = clamp(y, 0, sh)
                    setSel(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0))
                } else if (drag === "m") {
                    selX = clamp(d.sx + x - d.x, 0, sw - d.sw)
                    selY = clamp(d.sy + y - d.y, 0, sh - d.sh)
                } else {
                    let l = d.sx, t = d.sy, r = d.sx + d.sw, b = d.sy + d.sh
                    if (drag.indexOf("l") >= 0) l = clamp(x, 0, r - 8)
                    if (drag.indexOf("r") >= 0) r = clamp(x, l + 8, sw)
                    if (drag.indexOf("t") >= 0) t = clamp(y, 0, b - 8)
                    if (drag.indexOf("b") >= 0) b = clamp(y, t + 8, sh)
                    setSel(l, t, r - l, b - t)
                }
            }
            function release() {
                if (drag === "draw" && draft) {
                    const s = draft
                    const tiny = Math.abs(s.x1 - s.x0) < 3 && Math.abs(s.y1 - s.y0) < 3
                    const freehand = s.type === "pen" || s.type === "highlight"
                    draft = null
                    if (freehand ? s.pts.length > 1 : !tiny) addShape(s)
                } else if (drag === "new" && !hasSel) {
                    selW = 0; selH = 0
                }
                drag = ""
            }

            // ---- annotations ----------------------------------------------------------------
            function addShape(s) { shapes = shapes.concat([s]); redoStack = [] }
            function undo() {
                if (!shapes.length) return
                redoStack = redoStack.concat([shapes[shapes.length - 1]])
                shapes = shapes.slice(0, -1)
            }
            function redo() {
                if (!redoStack.length) return
                shapes = shapes.concat([redoStack[redoStack.length - 1]])
                redoStack = redoStack.slice(0, -1)
            }
            function commitText() {
                const t = txt.text.trim()
                if (t && textAt) addShape({ type: "text", x: textAt.x, y: textAt.y, text: t, color: "" + penColor, size: 14 + penWidth * 3 })
                textAt = null
                keys.forceActiveFocus()
            }
            onTextAtChanged: if (textAt) { txt.text = ""; txt.forceActiveFocus() }

            function drawShape(ctx, s) {
                ctx.save()
                ctx.strokeStyle = s.color
                ctx.fillStyle = s.color
                ctx.lineWidth = s.w || 4
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                if (s.type === "pen" || s.type === "highlight") {
                    if (s.type === "highlight") { ctx.globalAlpha = 0.35; ctx.lineWidth = s.w * 4; ctx.lineCap = "butt" }
                    ctx.beginPath()
                    ctx.moveTo(s.pts[0].x, s.pts[0].y)
                    for (let i = 1; i < s.pts.length; i++) ctx.lineTo(s.pts[i].x, s.pts[i].y)
                    ctx.stroke()
                } else if (s.type === "arrow") {
                    const a = Math.atan2(s.y1 - s.y0, s.x1 - s.x0), len = 10 + s.w * 2.5
                    ctx.beginPath()
                    ctx.moveTo(s.x0, s.y0); ctx.lineTo(s.x1, s.y1)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(s.x1, s.y1)
                    ctx.lineTo(s.x1 - len * Math.cos(a - 0.45), s.y1 - len * Math.sin(a - 0.45))
                    ctx.lineTo(s.x1 - len * Math.cos(a + 0.45), s.y1 - len * Math.sin(a + 0.45))
                    ctx.closePath()
                    ctx.fill()
                } else if (s.type === "rect") {
                    ctx.strokeRect(Math.min(s.x0, s.x1), Math.min(s.y0, s.y1), Math.abs(s.x1 - s.x0), Math.abs(s.y1 - s.y0))
                } else if (s.type === "oval") {
                    ctx.beginPath()
                    ctx.ellipse(Math.min(s.x0, s.x1), Math.min(s.y0, s.y1), Math.abs(s.x1 - s.x0), Math.abs(s.y1 - s.y0))
                    ctx.stroke()
                } else if (s.type === "text") {
                    ctx.font = s.size + "px sans-serif"
                    ctx.textBaseline = "top"
                    ctx.fillText(s.text, s.x, s.y)
                } else if (s.type === "step") {
                    const r = 11 + s.w * 1.5, c = Qt.color(s.color)
                    ctx.beginPath()
                    ctx.arc(s.x, s.y, r, 0, Math.PI * 2)
                    ctx.fill()
                    ctx.fillStyle = (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.6 ? "#000000" : "#ffffff"
                    ctx.font = "bold " + Math.round(r * 1.1) + "px sans-serif"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText("" + s.n, s.x, s.y + 1)
                }
                ctx.restore()
            }

            // ---- output ---------------------------------------------------------------------
            function output(kind) {
                if (!hasSel) return
                if (textAt) commitText()
                if (kind === "record") {
                    root.svc.record(modelData.x + selX, modelData.y + selY, selW, selH)
                    return
                }
                const path = root.svc.tmpPath()
                snap.grabToImage(r => {
                    if (r.saveToFile(path)) root.svc.finish(path, kind)
                    root.svc.cancel()
                }, Qt.size(Math.max(1, Math.round(selW * dpr)), Math.max(1, Math.round(selH * dpr))))
            }

            function key(e) {
                const ctrl = e.modifiers & Qt.ControlModifier
                const shift = e.modifiers & Qt.ShiftModifier
                if (e.key === Qt.Key_Escape) { root.svc.cancel(); return }
                if (ctrl && e.key === Qt.Key_Z) { if (shift) redo(); else undo(); return }
                if (ctrl && e.key === Qt.Key_Y) { redo(); return }
                if (ctrl && e.key === Qt.Key_C) { output("copy"); return }
                if (ctrl && e.key === Qt.Key_S) { output("save"); return }
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { output("copy"); return }
                if (!hasSel) return
                const step = shift ? 10 : 1
                if (e.key === Qt.Key_Left) selX = clamp(selX - step, 0, sw - selW)
                else if (e.key === Qt.Key_Right) selX = clamp(selX + step, 0, sw - selW)
                else if (e.key === Qt.Key_Up) selY = clamp(selY - step, 0, sh - selH)
                else if (e.key === Qt.Key_Down) selY = clamp(selY + step, 0, sh - selH)
                else if (!ctrl) {
                    const t = tools.find(x => x.key.charCodeAt(0) === e.key)
                    if (t) tool = t.id
                }
            }

            // ---- scene: what the image contains ---------------------------------------------
            Item {
                id: ui
                anchors.fill: parent
                opacity: win.ready ? 1 : 0     // see-through until the frame is in, so the grab is not dimmed

                Item {
                    id: scene
                    anchors.fill: parent

                    ScreencopyView {
                        id: frame
                        anchors.fill: parent
                        captureSource: win.modelData
                        live: false
                        paintCursor: false
                    }

                    Repeater {
                        model: win.blurs
                        ShaderEffectSource {
                            required property var modelData
                            readonly property real rx: Math.min(modelData.x0, modelData.x1)
                            readonly property real ry: Math.min(modelData.y0, modelData.y1)
                            x: rx; y: ry
                            width: Math.abs(modelData.x1 - modelData.x0)
                            height: Math.abs(modelData.y1 - modelData.y0)
                            sourceItem: frame
                            sourceRect: Qt.rect(rx, ry, width, height)
                            textureSize: Qt.size(Math.max(1, Math.round(width / 10)), Math.max(1, Math.round(height / 10)))
                            smooth: false
                        }
                    }

                    Canvas {
                        id: cv
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const all = win.draft ? win.shapes.concat([win.draft]) : win.shapes
                            for (const s of all) if (s.type !== "blur") win.drawShape(ctx, s)
                        }
                        Connections {
                            target: win
                            function onShapesChanged() { cv.requestPaint() }
                            function onDraftChanged() { cv.requestPaint() }
                        }
                    }
                }

                // the crop that gets saved; sits under the opaque scene
                ShaderEffectSource {
                    id: snap
                    z: -1
                    sourceItem: scene
                    sourceRect: Qt.rect(win.selX, win.selY, Math.max(1, win.selW), Math.max(1, win.selH))
                    width: Math.max(1, win.selW)
                    height: Math.max(1, win.selH)
                    textureSize: Qt.size(Math.max(1, Math.round(width * win.dpr)), Math.max(1, Math.round(height * win.dpr)))
                    live: win.hasSel
                }

                // ---- dim, selection, handles --------------------------------------------
                readonly property color dim: "#99000000"
                Rectangle { visible: !win.hasSel; anchors.fill: parent; color: ui.dim }
                Rectangle { visible: win.hasSel; x: 0; y: 0; width: parent.width; height: win.selY; color: ui.dim }
                Rectangle { visible: win.hasSel; x: 0; y: win.selY + win.selH; width: parent.width; height: parent.height - y; color: ui.dim }
                Rectangle { visible: win.hasSel; x: 0; y: win.selY; width: win.selX; height: win.selH; color: ui.dim }
                Rectangle { visible: win.hasSel; x: win.selX + win.selW; y: win.selY; width: parent.width - x; height: win.selH; color: ui.dim }

                Rectangle {
                    visible: win.hasSel
                    x: win.selX; y: win.selY; width: win.selW; height: win.selH
                    color: "transparent"
                    border { width: 1; color: Theme.accent }
                }
                Repeater {
                    model: win.hasSel && win.tool === "move" && win.mode !== "screen" ? [
                        [0, 0], [0.5, 0], [1, 0], [1, 0.5], [1, 1], [0.5, 1], [0, 1], [0, 0.5]
                    ] : []
                    Rectangle {
                        required property var modelData
                        width: 9; height: 9; radius: 2
                        x: win.selX + win.selW * modelData[0] - 4.5
                        y: win.selY + win.selH * modelData[1] - 4.5
                        color: Theme.accent
                        border { width: 1; color: "white" }
                    }
                }

                // window mode: the window under the pointer
                Rectangle {
                    visible: win.mode === "window" && !win.hasSel && win.hover !== null
                    x: win.hover ? win.hover.x : 0; y: win.hover ? win.hover.y : 0
                    width: win.hover ? win.hover.w : 0; height: win.hover ? win.hover.h : 0
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    border { width: 2; color: Theme.accent }
                }

                // size readout
                Rectangle {
                    visible: win.hasSel
                    x: win.clamp(win.selX, 0, win.sw - width)
                    y: win.selY > height + 6 ? win.selY - height - 4 : win.selY + 4
                    width: sizeText.implicitWidth + 12; height: 22; radius: 6
                    color: Theme.osdBg
                    Text {
                        id: sizeText
                        anchors.centerIn: parent
                        text: Math.round(win.selW * win.dpr) + " × " + Math.round(win.selH * win.dpr)
                        color: Theme.fg; font.pixelSize: 11
                    }
                }

                // hint before anything is selected
                Rectangle {
                    visible: !win.hasSel && win.drag === ""
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 48 }
                    width: hintText.implicitWidth + 28; height: 32; radius: 16
                    color: Theme.osdBg
                    Text {
                        id: hintText
                        anchors.centerIn: parent
                        color: Theme.fg; font.pixelSize: 12
                        text: win.mode === "window" ? "Click a window · Esc cancel" : "Drag to select an area · Esc cancel"
                    }
                }

                // ---- pointer ------------------------------------------------------------
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: win.cursorFor(win.drag === "" || win.drag === "draw" ? (win.hasSel ? win.handleAt(mouseX, mouseY) : "") : win.drag)
                    onPressed: m => win.press(m.x, m.y)
                    onPositionChanged: m => win.move(m.x, m.y)
                    onReleased: win.release()
                }

                // ---- text tool ----------------------------------------------------------
                Rectangle {
                    visible: win.textAt !== null
                    x: win.textAt ? win.textAt.x - 3 : 0
                    y: win.textAt ? win.textAt.y - 2 : 0
                    width: Math.max(40, txt.implicitWidth) + 6; height: txt.implicitHeight + 4
                    color: "#44000000"
                    border { width: 1; color: Theme.accent }
                    TextInput {
                        id: txt
                        x: 3; y: 2
                        color: win.penColor
                        font.pixelSize: 14 + win.penWidth * 3
                        onAccepted: win.commitText()
                        Keys.onEscapePressed: { win.textAt = null; keys.forceActiveFocus() }
                    }
                }

                // ---- toolbar ------------------------------------------------------------
                Rectangle {
                    id: bar
                    visible: win.hasSel && win.drag !== "new" && win.drag !== "m" && win.drag.length < 3
                    width: barCol.implicitWidth + 20
                    height: barCol.implicitHeight + 20
                    x: win.clamp(win.selX + win.selW / 2 - width / 2, 8, win.sw - width - 8)
                    y: {
                        const below = win.selY + win.selH + 12
                        if (below + height < win.sh - 8) return below
                        const above = win.selY - height - 12
                        return above > 8 ? above : win.clamp(win.selY + win.selH - height - 12, 8, win.sh - height - 8)
                    }
                    radius: 14
                    color: Theme.popoverBg
                    border { width: 1; color: Theme.border }

                    MouseArea { anchors.fill: parent; hoverEnabled: true }   // keep clicks off the selection layer

                    Column {
                        id: barCol
                        anchors.centerIn: parent
                        spacing: 8

                        Row {
                            spacing: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            Repeater {
                                model: [{ id: "region", label: "Region" }, { id: "window", label: "Window" }, { id: "screen", label: "Screen" }]
                                Chip {
                                    required property var modelData
                                    label: modelData.label
                                    active: win.mode === modelData.id
                                    onClicked: win.setMode(modelData.id)
                                }
                            }
                            Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.border }
                            Repeater {
                                model: win.tools
                                Chip {
                                    required property var modelData
                                    label: modelData.label
                                    active: win.tool === modelData.id
                                    onClicked: win.tool = modelData.id
                                }
                            }
                        }

                        Row {
                            spacing: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            Repeater {
                                model: win.palette
                                Rectangle {
                                    id: swatch
                                    required property string modelData
                                    readonly property bool picked: win.penColor.toString() === Qt.color(modelData).toString()
                                    width: 22; height: 22; radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData
                                    border { width: picked ? 3 : 1; color: picked ? Theme.accent : Theme.border }
                                    MouseArea { anchors.fill: parent; onClicked: win.penColor = swatch.modelData }
                                }
                            }
                            Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.border }
                            Repeater {
                                model: [{ label: "S", w: 2 }, { label: "M", w: 4 }, { label: "L", w: 8 }]
                                Chip {
                                    required property var modelData
                                    label: modelData.label
                                    active: win.penWidth === modelData.w
                                    onClicked: win.penWidth = modelData.w
                                }
                            }
                            Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.border }
                            Chip { label: "Undo"; opacity: win.shapes.length > 0 ? 1 : 0.4; onClicked: win.undo() }
                            Chip { label: "Redo"; opacity: win.redoStack.length > 0 ? 1 : 0.4; onClicked: win.redo() }
                            Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.border }
                            Chip { label: "Copy"; active: true; onClicked: win.output("copy") }
                            Chip { label: "Save"; onClicked: win.output("save") }
                            Chip { label: "OCR"; onClicked: win.output("ocr") }
                            Chip { label: "Record"; visible: QuickService.hasRecorder; onClicked: win.output("record") }
                            Chip { label: "✕"; destructive: true; onClicked: root.svc.cancel() }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Theme.faint; font.pixelSize: 11
                            text: "Enter copy · Ctrl+S save · Ctrl+Z undo · V P A R O H T N B tools · arrows nudge · Esc cancel"
                        }
                    }
                }

                // keyboard
                FocusScope {
                    anchors.fill: parent
                    Item {
                        id: keys
                        focus: true
                        Keys.onPressed: e => { win.key(e); e.accepted = true }
                    }
                }
            }
        }
    }

    // countdown pill while a delayed capture waits
    PanelWindow {
        screen: Quickshell.screens[0]
        visible: root.svc.countingDown
        color: "transparent"
        anchors.top: true
        margins.top: 80
        implicitWidth: 120
        implicitHeight: 120
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screenshot-countdown"

        Rectangle {
            anchors.fill: parent
            radius: 60
            color: Theme.osdBg
            border { width: 2; color: Theme.accent }
            Text { anchors.centerIn: parent; text: root.svc.countdown; color: Theme.fg; font { pixelSize: 56; bold: true } }
            MouseArea { anchors.fill: parent; onClicked: root.svc.cancel() }
        }
    }
}
