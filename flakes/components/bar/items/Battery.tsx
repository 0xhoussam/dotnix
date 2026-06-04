import { createBinding } from "ags"
import AstalBattery from "gi://AstalBattery"

// Battery icon + percentage. Hidden when no battery present.
export function Battery() {
  const bat = AstalBattery.get_default()
  const present = createBinding(bat, "isPresent")
  const icon = createBinding(bat, "batteryIconName")
  const pct = createBinding(bat, "percentage")

  return (
    <box class="battery" visible={present} spacing={4}>
      <image iconName={icon} pixelSize={16} />
      <label label={pct((p) => `${Math.round(p * 100)}%`)} />
    </box>
  )
}
