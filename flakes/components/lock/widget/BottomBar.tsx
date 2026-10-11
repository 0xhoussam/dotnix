import { Gtk } from "ags/gtk4"
import { createState } from "ags"
import { execAsync } from "ags/process"
import GLib from "gi://GLib"

const SESSION = (GLib.getenv("XDG_CURRENT_DESKTOP") ?? "").split(":")[0] || "Wayland"

// Power action that needs a second click within a few seconds.
function PowerButton({ label, command }: { label: string; command: string[] }) {
  const [armed, setArmed] = createState(false)
  let timer = 0
  const click = () => {
    if (!armed.get()) {
      setArmed(true)
      if (timer) GLib.source_remove(timer)
      timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 4, () => {
        setArmed(false)
        timer = 0
        return GLib.SOURCE_REMOVE
      })
      return
    }
    setArmed(false)
    execAsync(command).catch((e) => console.error(`lock: ${label}:`, e))
  }
  return (
    <button class={armed((a) => `power-btn${a ? " armed" : ""}`)} onClicked={click} focusOnClick={false}>
      <label label={armed((a) => (a ? `CONFIRM ${label}?` : label))} />
    </button>
  )
}

// "• HYPRLAND ............ RESTART  SHUT DOWN" over a hairline.
export default function BottomBar() {
  return (
    <box class="bottom" orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.END}>
      <box class="bottom-row" spacing={24}>
        <box class="session" spacing={10} hexpand valign={Gtk.Align.CENTER}>
          <box class="session-dot" valign={Gtk.Align.CENTER} />
          <label class="session-name" label={SESSION.toUpperCase()} />
        </box>
        <PowerButton label="RESTART" command={["systemctl", "reboot"]} />
        <PowerButton label="SHUT DOWN" command={["systemctl", "poweroff"]} />
      </box>
      <box class="bottom-line" />
    </box>
  )
}
