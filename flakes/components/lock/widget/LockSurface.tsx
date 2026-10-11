import { Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import { Background, noteInput } from "./Background"
import BottomBar from "./BottomBar"
import Clock from "./Clock"
import LoginBox from "./LoginBox"

// One surface per monitor: wallpaper, a legibility scrim, then the clock
// (top-left), password field (right) and bottom bar on top.
export default function LockSurface({ onSuccess }: { onSuccess: () => void }) {
  return (
    <overlay
      class="lock-surface"
      $={(self) => {
        // any input resumes an idle-paused video
        const keys = new Gtk.EventControllerKey()
        keys.connect("key-pressed", () => (noteInput(), false))
        const motion = new Gtk.EventControllerMotion()
        motion.connect("motion", noteInput)
        self.add_controller(keys)
        self.add_controller(motion)
      }}
    >
      <Background />
      <box $type="overlay" class="lock-scrim" hexpand vexpand canTarget={false} />
      <box $type="overlay" class="lock-content" orientation={Gtk.Orientation.VERTICAL} hexpand vexpand
        $={(self) =>
          // a frame after mapping so the opacity transition actually runs
          self.connect("map", () =>
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60, () => (self.add_css_class("shown"), GLib.SOURCE_REMOVE)))
        }>
        <Clock />
        <box vexpand />
        <LoginBox onSuccess={onSuccess} />
        <BottomBar />
      </box>
    </overlay>
  )
}
