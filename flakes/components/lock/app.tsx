import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import Gtk4SessionLock from "gi://Gtk4SessionLock"
import style from "./style.scss"
import { startIdlePause, wallpaper } from "./widget/Background"
import LockSurface from "./widget/LockSurface"

// Secure lock screen on ext-session-lock-v1 (gtk4-layer-shell's
// Gtk4SessionLock): the compositor keeps every output locked until we
// unlock after a successful PAM conversation, or shows its own failsafe
// if this process dies.
//
// LOCK_PREVIEW=1 renders the same surfaces as plain overlay windows without
// locking anything (Escape quits) — for working on the design.

const PREVIEW = GLib.getenv("LOCK_PREVIEW") === "1"

function surface(onSuccess: () => void) {
  return <LockSurface onSuccess={onSuccess} />
}

function fadeOutThen(done: () => void) {
  for (const w of app.get_windows()) w.add_css_class("leaving")
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 260, () => (done(), GLib.SOURCE_REMOVE))
}

function startLock() {
  if (!Gtk4SessionLock.is_supported()) {
    console.error("lock: ext-session-lock-v1 not supported by this compositor")
    return app.quit()
  }

  const lock = Gtk4SessionLock.Instance.new()
  const unlock = () => fadeOutThen(() => lock.unlock())

  lock.connect("failed", () => {
    console.error("lock: compositor refused the lock (another locker running?)")
    app.quit()
  })
  lock.connect("unlocked", () => app.quit())
  // emitted for every output now and for any plugged in while locked
  lock.connect("monitor", (_l: Gtk4SessionLock.Instance, monitor: Gdk.Monitor) => {
    const win = new Gtk.Window({ application: app, cssClasses: ["lock-window"] })
    win.set_child(surface(unlock) as Gtk.Widget)
    lock.assign_window_to_monitor(win, monitor)
    win.present()
  })

  if (!lock.lock()) {
    console.error("lock: lock() failed")
    app.quit()
  }
}

function startPreview() {
  for (const monitor of app.get_monitors()) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    const win = (
      <window
        visible
        gdkmonitor={monitor}
        namespace="lock-preview"
        class="lock-window"
        layer={Astal.Layer.OVERLAY}
        exclusivity={Astal.Exclusivity.IGNORE}
        keymode={Astal.Keymode.EXCLUSIVE}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        application={app}
      >
        {surface(() => fadeOutThen(() => app.quit()))}
      </window>
    ) as Gtk.Window
    const keys = new Gtk.EventControllerKey()
    keys.propagationPhase = Gtk.PropagationPhase.CAPTURE
    keys.connect("key-pressed", (_c, keyval, _code, state) => {
      // Ctrl+Escape: Escape alone clears the password field
      if (keyval === Gdk.KEY_Escape && state & Gdk.ModifierType.CONTROL_MASK) app.quit()
      return false
    })
    win.add_controller(keys)
  }
}

app.start({
  instanceName: PREVIEW ? "lock-preview" : "lock",
  css: style,
  main() {
    wallpaper() // start decoding before the surfaces map
    startIdlePause()
    PREVIEW ? startPreview() : startLock()
  },
})
