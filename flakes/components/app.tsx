import "./bar/preinit" // must stay first: clears dark-theme flag pre Adw.init
import app from "ags/gtk4/app"
import Adw from "gi://Adw?version=1"
import style from "./bar/style.scss"
import Bar from "./bar/app"
import DatePanel from "./bar/widget/DatePanel"
import NotificationPopups from "./bar/widget/NotificationPopups"

app.start({
  css: style,
  main() {
    Adw.StyleManager.get_default().colorScheme = Adw.ColorScheme.FORCE_DARK

    const monitors = app.get_monitors()
    monitors.map(Bar)

    // Single-instance overlays on the primary monitor.
    const primary = monitors[0]
    if (primary) {
      DatePanel(primary)
      NotificationPopups(primary)
    }
  },
})
