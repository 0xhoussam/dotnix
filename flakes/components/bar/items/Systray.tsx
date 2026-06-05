import { Gtk } from "ags/gtk4"
import { createBinding, For } from "ags"
import AstalTray from "gi://AstalTray"

// StatusNotifierItem system tray. Each app-provided item renders as a
// menubutton: left/right click opens its dbusmenu popover. Item count and
// each item's icon/menu are dynamic, so everything is bound.
export function Systray() {
  const tray = AstalTray.get_default()
  const items = createBinding(tray, "items")

  return (
    <box class="systray" visible={items((l) => l.length > 0)}>
      <For each={items}>
        {(item: AstalTray.TrayItem) => <TrayItem item={item} />}
      </For>
    </box>
  )
}

function TrayItem({ item }: { item: AstalTray.TrayItem }) {
  const gicon = createBinding(item, "gicon")
  const tooltip = createBinding(item, "tooltipMarkup")

  // menuModel / actionGroup can be swapped by the app at runtime; re-bind on
  // change so the popover menu always reflects the current dbusmenu.
  const wire = (self: Gtk.MenuButton) => {
    const apply = () => {
      self.menuModel = item.menuModel
      self.insert_action_group("dbusmenu", item.actionGroup)
    }
    apply()
    item.connect("notify::menu-model", apply)
    item.connect("notify::action-group", apply)
  }

  return (
    <menubutton class="systray-item" tooltipMarkup={tooltip} $={wire}>
      <image gicon={gicon} pixelSize={16} />
    </menubutton>
  )
}
