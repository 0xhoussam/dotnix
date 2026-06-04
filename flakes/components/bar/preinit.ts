// Must be imported BEFORE "ags/gtk4/app".
// That module runs Gtk.init() then Adw.init() at import time. Adw.init()
// warns when GtkSettings:gtk-application-prefer-dark-theme is set (it is,
// globally, in ~/.config/gtk-4.0/settings.ini). Clear it here first; dark
// mode is then applied the supported way via AdwStyleManager (see app.tsx).
import Gtk from "gi://Gtk?version=4.0"

Gtk.init()
const settings = Gtk.Settings.get_default()
if (settings) settings.gtkApplicationPreferDarkTheme = false
