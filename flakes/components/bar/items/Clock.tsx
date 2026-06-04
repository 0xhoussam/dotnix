import GLib from "gi://GLib"
import { createPoll } from "ags/time"
import { panelOpen, togglePanel } from "../state"

// Center clock: "Jun 04  12:16". Click toggles the date/notification panel.
export function Clock() {
  const time = createPoll("", 1000, () =>
    GLib.DateTime.new_now_local().format("%b %d  %H:%M")!,
  )

  return (
    <button
      class={panelOpen((o) => `clock${o ? " active" : ""}`)}
      onClicked={togglePanel}
    >
      <label label={time} />
    </button>
  )
}
