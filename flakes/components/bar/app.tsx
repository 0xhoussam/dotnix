import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { createState, type Accessor, type Setter } from "ags"
import GLib from "gi://GLib"
import cairo from "gi://cairo"
import { config, type Location } from "./config"
import { panelOpen } from "./state"
import { Workspaces } from "./items/Workspaces"
import { Clock } from "./items/Clock"
import { Keyboard } from "./items/Keyboard"
import { Network } from "./items/network"
import { Bluetooth } from "./items/bluetooth"
import { Volume } from "./items/Volume"
import { Battery } from "./items/Battery"
import { Clipboard } from "./items/Clipboard"
import { Settings } from "./items/Settings"
import { Systray } from "./items/Systray"
import { Logo } from "./items/Logo"

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  // Module registry. Each entry builds the widget for that module name.
  const Bar_Items: Record<string, () => any> = {
    logo: () => <Logo />,
    workspaces: () => <Workspaces gdkmonitor={gdkmonitor} />,
    clock: () => <Clock />,
    keyboard: () => <Keyboard />,
    network: () => <Network />,
    bluetooth: () => <Bluetooth />,
    volume: () => <Volume />,
    battery: () => <Battery />,
    clipboard: () => <Clipboard />,
    settings: () => <Settings />,
    systray: () => <Systray />,
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

  const bottom = config.position === "bottom"
  const { enabled: autohide, revealZone, transition } = config.autohide
  // Autohide still starts shown: a layer surface first mapped with the bar
  // collapsed gets a bogus size from Hyprland and never receives the pointer.
  // setupAutohide hides it once mapped.
  const [shown, setShown] = createState(true)

  return (
    <window
      visible
      name="bar"
      class={autohide ? "Bar autohide" : "Bar"}
      gdkmonitor={gdkmonitor}
      exclusivity={autohide ? Astal.Exclusivity.NONE : Astal.Exclusivity.EXCLUSIVE}
      anchor={bottom ? Astal.WindowAnchor.BOTTOM | LEFT | RIGHT : TOP | LEFT | RIGHT}
      application={app}
      $={(self) => autohide && setupAutohide(self, shown, setShown)}
    >
      {/* The window keeps the full bar height even while hidden (resizing a
          layer surface on the fly is unreliable); hiding only collapses the
          revealer and shrinks the input region to the edge strip. */}
      <box heightRequest={config.size}>
        <revealer
          hexpand
          valign={bottom ? Gtk.Align.END : Gtk.Align.START}
          revealChild={shown}
          transitionDuration={transition}
          transitionType={bottom ? Gtk.RevealerTransitionType.SLIDE_UP : Gtk.RevealerTransitionType.SLIDE_DOWN}
        >
          <centerbox cssName="centerbox" class="bar-body" $={(self) => (self.heightRequest = config.size)}>
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
        </revealer>
      </box>
    </window>
  )
}

const TICK = 150 // ms between hide checks while the bar is shown

// Show on pointer enter; hide once nothing has held the bar for `hideDelay`.
// Holds: pointer over the bar, an open popover (tray menus, network,
// bluetooth, clipboard) or the date panel. Polled rather than tracked with
// leave events, since popovers live on their own surfaces.
function setupAutohide(win: Astal.Window, shown: Accessor<boolean>, setShown: Setter<boolean>) {
  const motion = new Gtk.EventControllerMotion()
  win.add_controller(motion)

  // Hidden: only a `revealZone` strip at the screen edge takes input, the
  // rest of the transparent window is click-through. Shown: the whole bar.
  const updateInput = () => {
    const { size, position } = config
    const zone = config.autohide.revealZone
    const region = new cairo.Region()
    if (shown.get()) region.unionRectangle({ x: 0, y: 0, width: 1 << 16, height: size })
    else region.unionRectangle({ x: 0, y: position === "bottom" ? size - zone : 0, width: 1 << 16, height: zone })
    win.get_surface()?.set_input_region(region)
  }
  win.connect("realize", updateInput)
  shown.subscribe(updateInput)

  const held = () => motion.containsPointer || panelOpen.get() || hasOpenPopover(win)

  let timer = 0
  const reveal = () => {
    if (!shown.get()) setShown(true)
    if (timer) return
    let idle = 0
    timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, TICK, () => {
      idle = held() ? 0 : idle + TICK
      if (idle < config.autohide.hideDelay) return GLib.SOURCE_CONTINUE
      timer = 0
      setShown(false)
      return GLib.SOURCE_REMOVE
    })
  }

  motion.connect("enter", reveal)
  // Initial peek: start the hide countdown once the bar is on screen.
  if (win.get_mapped()) reveal()
  else win.connect("map", reveal)
  // Opening the date panel (e.g. from a keybind) shows the bar too.
  panelOpen.subscribe(() => panelOpen.get() && reveal())
}

function hasOpenPopover(w: Gtk.Widget): boolean {
  if (w instanceof Gtk.Popover && w.visible) return true
  for (let c = w.get_first_child(); c; c = c.get_next_sibling()) if (hasOpenPopover(c)) return true
  return false
}
