import { createState } from "ags"
import Hyprland from "gi://AstalHyprland"

// "English (US)" -> "En", "French" -> "Fr"
function short(layout: string): string {
  const w = layout.trim()
  return (w[0] ?? "").toUpperCase() + (w[1] ?? "").toLowerCase()
}

// Active Hyprland keyboard layout. Hyprland exposes no current-layout getter;
// it only emits `keyboard-layout` on change, so seed with a placeholder.
export function Keyboard() {
  const hypr = Hyprland.get_default()
  const [layout, setLayout] = createState("En")

  hypr.connect("keyboard-layout", (_h, _kbd: string, lay: string) => {
    setLayout(short(lay))
  })

  return (
    <button class="keyboard">
      <label label={layout} />
    </button>
  )
}
