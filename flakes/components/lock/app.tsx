/** @jsxImportSource ags/gtk3 */
import app from "ags/gtk3/app"
import Gtk from "gi://Gtk?version=3.0"
import Gdk from "gi://Gdk?version=3.0"
import GLib from "gi://GLib?version=2.0"
import GtkSessionLock from "gi://GtkSessionLock?version=0.1"
import style from "./style.scss"
import LockSurface from "./widget/LockSurface"
import { WALLPAPER } from "./config"

const lock = GtkSessionLock.prepare_lock()

function unlock() {
  for (const win of app.get_windows()) {
    GtkSessionLock.unmap_lock_window(win)
  }
  lock.unlock_and_destroy()
  Gdk.Display.get_default()?.sync()
  app.quit()
}

// Walk the widget tree to find the password entry so we can focus it.
function findEntry(widget: Gtk.Widget): Gtk.Entry | null {
  if (widget instanceof Gtk.Entry) return widget
  if (widget instanceof Gtk.Container) {
    for (const child of widget.get_children()) {
      const found = findEntry(child)
      if (found) return found
    }
  }
  return null
}

app.start({
  css: style,
  main() {
    if (!GtkSessionLock.is_supported()) {
      console.error("ext-session-lock-v1 not supported by this compositor")
      return app.quit()
    }

    // wallpaper overrides the gradient when a valid path is configured
    if (WALLPAPER && GLib.file_test(WALLPAPER, GLib.FileTest.EXISTS)) {
      app.apply_css(
        `.lock-surface {
           background-image: url("file://${WALLPAPER}");
           background-size: cover;
           background-position: center;
         }`,
        false,
      )
    }

    lock.connect("finished", () => {
      console.error("session lock finished without locking")
      app.quit()
    })

    let passwordEntry: Gtk.Entry | null = null
    lock.connect("locked", () => {
      console.log("session locked")
      passwordEntry?.grab_focus()
    })

    lock.lock_lock()

    const display = Gdk.Display.get_default()
    const primaryMon = display?.get_primary_monitor() ?? null
    const monitors = app.get_monitors()

    for (const monitor of monitors) {
      const isPrimary = primaryMon ? monitor === primaryMon : monitor === monitors[0]

      const win = new Gtk.Window()
      win.set_decorated(false)
      win.add(LockSurface(isPrimary, unlock))

      lock.new_surface(win, monitor)
      win.show_all()
      app.add_window(win)

      if (isPrimary) passwordEntry = findEntry(win)
    }
  },
})
