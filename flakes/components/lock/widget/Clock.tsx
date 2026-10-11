import { Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import { createPoll } from "ags/time"

const now = () => GLib.DateTime.new_now_local()

// Big clock top-left with a cyan "— SUNDAY · OCTOBER 11" line under it.
export default function Clock() {
  const time = createPoll(now().format("%H:%M")!, 1000, () => now().format("%H:%M")!)
  const date = createPoll(now().format("%A · %B %-d")!.toUpperCase(), 30_000, () =>
    now().format("%A · %B %-d")!.toUpperCase(),
  )

  return (
    <box class="clock" orientation={Gtk.Orientation.VERTICAL} halign={Gtk.Align.START} valign={Gtk.Align.START}>
      <label class="clock-time" label={time} xalign={0} />
      <box class="clock-date-row" spacing={12}>
        <box class="clock-dash" valign={Gtk.Align.CENTER} />
        <label class="clock-date" label={date} xalign={0} />
      </box>
    </box>
  )
}
