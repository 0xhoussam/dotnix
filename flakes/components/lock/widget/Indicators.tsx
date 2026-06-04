/** @jsxImportSource ags/gtk3 */
import Gtk from "gi://Gtk?version=3.0"
import AstalHyprland from "gi://AstalHyprland?version=0.1"
import AstalNetwork from "gi://AstalNetwork?version=0.1"
import AstalBattery from "gi://AstalBattery?version=0.1"
import { createState, createBinding } from "ags"

function Keyboard() {
  let hypr: AstalHyprland.Hyprland | null = null
  try {
    hypr = AstalHyprland.get_default()
  } catch {
    return <box />
  }
  if (!hypr) return <box />

  // Initial layout from `hyprctl devices`; signal updates it on switch.
  let initial = ""
  try {
    const data = JSON.parse(hypr.message("devices"))
    const kbs: Array<{ main?: boolean; active_keymap?: string }> =
      data.keyboards ?? []
    const main = kbs.find((k) => k.main) ?? kbs[0]
    initial = main?.active_keymap ?? ""
  } catch {
    // ignore; start blank
  }

  const [layout, setLayout] = createState(initial)
  hypr.connect("keyboard-layout", (_h, _kb: string, l: string) => setLayout(l))

  return (
    <box class="chip" spacing={6}>
      <label class="chip-text" label={layout} />
      <icon icon="input-keyboard-symbolic" />
    </box>
  )
}

function WiFi() {
  const net = AstalNetwork.get_default()
  const wifi = net.wifi
  if (!wifi) return <box />
  return <icon class="chip-icon" icon={createBinding(wifi, "iconName")} />
}

function Battery() {
  const bat = AstalBattery.get_default()
  if (!bat.isPresent) return <box />
  return (
    <box class="chip" spacing={4}>
      <icon icon={createBinding(bat, "iconName")} />
      <label
        class="chip-text"
        label={createBinding(bat, "percentage").as(
          (p) => `${Math.round(p * 100)}%`,
        )}
      />
    </box>
  )
}

export default function Indicators() {
  return (
    <box
      class="indicators"
      halign={Gtk.Align.END}
      valign={Gtk.Align.START}
      spacing={12}
    >
      <Keyboard />
      <WiFi />
      <Battery />
    </box>
  )
}
