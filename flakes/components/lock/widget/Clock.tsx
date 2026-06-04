/** @jsxImportSource ags/gtk3 */
import Gtk from "gi://Gtk?version=3.0"
import GLib from "gi://GLib?version=2.0"
import { createPoll } from "ags/time"

// Reactive clock. Time updates each second, date every 30s.
export default function Clock() {
  const time = createPoll("", 1000, () =>
    GLib.DateTime.new_now_local().format("%H:%M")!,
  )
  const date = createPoll("", 30_000, () =>
    GLib.DateTime.new_now_local().format("%A, %B %-d")!,
  )

  return (
    <box class="clock" vertical halign={Gtk.Align.CENTER}>
      <label class="clock-date" label={date} />
      <label class="clock-time" label={time} />
    </box>
  )
}
