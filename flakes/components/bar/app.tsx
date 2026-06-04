import app from "ags/gtk4/app"
import { Astal, Gdk } from "ags/gtk4"
import { config, type Location } from "./config"
import { Workspaces } from "./items/Workspaces"
import { Clock } from "./items/Clock"
import { Keyboard } from "./items/Keyboard"
import { Network } from "./items/Network"
import { Bluetooth } from "./items/Bluetooth"
import { Volume } from "./items/Volume"
import { Battery } from "./items/Battery"
import { Clipboard } from "./items/Clipboard"
import { Settings } from "./items/Settings"

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  // Module registry. Each entry builds the widget for that module name.
  const Bar_Items: Record<string, () => any> = {
    workspaces: () => <Workspaces gdkmonitor={gdkmonitor} />,
    clock: () => <Clock />,
    keyboard: () => <Keyboard />,
    network: () => <Network />,
    bluetooth: () => <Bluetooth />,
    volume: () => <Volume />,
    battery: () => <Battery />,
    clipboard: () => <Clipboard />,
    settings: () => <Settings />,
  }

  const getModules = (location: Location) =>
    config.modules[location]
      .map((name) => {
        const Widget = Bar_Items[name]
        if (!Widget) {
          console.error(`Bar: unknown module '${name}' in ${location} section`)
          return null
        }
        return Widget()
      })
      .filter((w) => w !== null)

  return (
    <window
      visible
      name="bar"
      class="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={config.position === "bottom" ? Astal.WindowAnchor.BOTTOM | LEFT | RIGHT : TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox cssName="centerbox" $={(self) => (self.heightRequest = config.size)}>
        <box $type="start" class="modules-start" spacing={config.spacing}>
          {getModules("start")}
        </box>
        <box $type="center" class="modules-center" spacing={config.spacing}>
          {getModules("center")}
        </box>
        <box $type="end" class="modules-end" spacing={config.spacing}>
          {getModules("end")}
        </box>
      </centerbox>
    </window>
  )
}
