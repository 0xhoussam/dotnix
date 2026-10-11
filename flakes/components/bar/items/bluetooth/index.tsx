import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createExternal, createState, For } from "ags"
import AstalBluetooth from "gi://AstalBluetooth"
import { AdapterSection } from "./AdapterSection"
import { DeviceRow } from "./DeviceRow"
import { cancelTransfer, transferLabel, transfers, type Transfer } from "./obex"
import { rfkill, unblock } from "./rfkill"
import { batteryPct, displayName, errorText, settings, updateSettings, type BtSettings } from "./util"

type Device = AstalBluetooth.Device

interface Sections {
  connected: Device[]
  paired: Device[]
  nearby: Device[]
}

const byName = (a: Device, b: Device) => displayName(a).localeCompare(displayName(b))

function computeSections(bt: AstalBluetooth.Bluetooth): Sections {
  const showUnnamed = settings.get().showUnnamed
  const all = bt.devices
  return {
    connected: all.filter((d) => d.connected).sort(byName),
    paired: all.filter((d) => d.paired && !d.connected).sort(byName),
    nearby: all
      .filter((d) => !d.paired && !d.connected && (showUnnamed || d.name))
      .sort((a, b) => (b.rssi || -999) - (a.rssi || -999))
      .slice(0, 25),
  }
}

// Device lists that also re-sort when a device's state (not just the device
// array) changes: connected / paired / name / rssi.
function createSections(bt: AstalBluetooth.Bluetooth) {
  return createExternal(computeSections(bt), (set) => {
    const handlers = new Map<Device, number[]>()
    const update = () => set(computeSections(bt))
    const watch = (d: Device) =>
      handlers.set(d, ["connected", "paired", "name", "alias"].map((p) => d.connect(`notify::${p}`, update)))
    const unwatch = (d: Device) => {
      handlers.get(d)?.forEach((id) => d.disconnect(id))
      handlers.delete(d)
    }

    bt.devices.forEach(watch)
    update()
    const added = bt.connect("device-added", (_b, d) => (watch(d), update()))
    const removed = bt.connect("device-removed", (_b, d) => (unwatch(d), update()))
    const unsub = settings.subscribe(update)

    return () => {
      bt.disconnect(added)
      bt.disconnect(removed)
      unsub()
      ;[...handlers.keys()].forEach(unwatch)
    }
  })
}

// Bluetooth indicator + popover: power, discoverable, devices (connected /
// my devices / nearby) with per-device panels, file transfers, options.
export function Bluetooth() {
  const bt = AstalBluetooth.get_default()

  const powered = createBinding(bt, "isPowered")
  const connected = createBinding(bt, "isConnected")
  const discovering = createBinding(bt, "adapter", "discovering")((d) => !!d)
  const sections = createSections(bt)
  const expanded = createState<string | null>(null)
  const [powerError, setPowerError] = createState<string | null>(null)

  const barIcon = createComputed(() =>
    rfkill().hard || !powered()
      ? "bluetooth-disabled-symbolic"
      : connected()
        ? "bluetooth-active-symbolic"
        : "bluetooth-symbolic",
  )

  const tooltip = createComputed(() => {
    if (rfkill().hard) return "Bluetooth blocked by hardware switch"
    if (!powered()) return "Bluetooth off"
    const list = sections().connected
    if (!list.length) return "Bluetooth on"
    return list
      .map((d) => {
        const pct = batteryPct(d.batteryPercentage)
        return pct >= 0 ? `${displayName(d)} · ${pct}%` : displayName(d)
      })
      .join("\n")
  })

  let popoverOpen = false
  let weStarted = false
  const startScan = () => {
    const a = bt.adapter
    if (!a?.powered || a.discovering) return
    try {
      a.start_discovery()
      weStarted = true
    } catch {
      // busy / not ready
    }
  }
  const stopScan = () => {
    if (!weStarted) return
    weStarted = false
    try {
      bt.adapter?.stop_discovery()
    } catch {
      // already stopped
    }
  }
  bt.connect("notify::is-powered", () => {
    if (bt.isPowered && popoverOpen) startScan()
  })

  const setPower = async (on: boolean) => {
    setPowerError(null)
    try {
      if (on) await unblock()
      const a = bt.adapter
      if (!a) throw new Error("No Bluetooth adapter found")
      a.powered = on
      if (on && popoverOpen) startScan()
    } catch (e) {
      setPowerError(errorText(e))
    }
  }

  const Section = ({ title, list }: { title: string; list: (s: Sections) => Device[] }) => {
    const items = sections(list)
    return (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={6} visible={items((l) => l.length > 0)}>
        <label class="net-section-title" label={title} halign={Gtk.Align.START} />
        <For each={items}>{(d: Device) => <DeviceRow device={d} expanded={expanded} />}</For>
      </box>
    )
  }

  const empty = sections((s) => !s.connected.length && !s.paired.length && !s.nearby.length)

  return (
    <menubutton class="bluetooth" tooltipText={tooltip}>
      <image iconName={barIcon} pixelSize={16} />
      <popover
        class="net-popover bt-popover"
        $={(self) =>
          self.connect("notify::visible", () => {
            popoverOpen = self.visible
            if (self.visible) startScan()
            else stopScan()
          })
        }
      >
        <box class="net-panel" orientation={Gtk.Orientation.VERTICAL}>
          <box class="net-header" spacing={6}>
            <label label="Bluetooth" hexpand halign={Gtk.Align.START} />
            <Gtk.Spinner visible={discovering} $={(self) => self.connect("map", () => self.start())} />
            <button
              class="bt-icon-btn"
              tooltipText="Scan again"
              visible={createComputed(() => powered() && !discovering())}
              onClicked={startScan}
            >
              <image iconName="view-refresh-symbolic" pixelSize={14} />
            </button>
            <switch
              class="net-switch"
              valign={Gtk.Align.CENTER}
              active={powered}
              sensitive={rfkill((r) => !r.hard)}
              $={(self) =>
                self.connect("notify::active", () => {
                  if (self.active !== bt.isPowered) void setPower(self.active)
                })
              }
            />
          </box>

          <label
            class="bt-banner"
            wrap
            xalign={0}
            visible={createComputed(() => rfkill().hard || !!powerError())}
            label={createComputed(() =>
              rfkill().hard
                ? "Bluetooth is blocked by a hardware switch or airplane mode."
                : (powerError() ?? ""),
            )}
          />

          <box class="net-body" orientation={Gtk.Orientation.VERTICAL} spacing={8} visible={powered}>
            <AdapterSection />

            <TransferList />

            <Gtk.ScrolledWindow
              class="bt-scroll"
              propagateNaturalHeight
              maxContentHeight={420}
              hscrollbarPolicy={Gtk.PolicyType.NEVER}
            >
              <box class="net-list" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
                <label
                  class="net-empty"
                  label={discovering((d) => (d ? "Searching for devices…" : "No devices found"))}
                  visible={empty}
                />
                <Section title="Connected" list={(s) => s.connected} />
                <Section title="My Devices" list={(s) => s.paired} />
                <Section title="Nearby" list={(s) => s.nearby} />
              </box>
            </Gtk.ScrolledWindow>
          </box>

          <Options />
        </box>
      </popover>
    </menubutton>
  )
}

function TransferList() {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={6} visible={transfers((t) => t.length > 0)}>
      <label class="net-section-title" label="Transfers" halign={Gtk.Align.START} />
      <For each={transfers}>
        {(t: Transfer) => {
          const live = transfers((list) => list.find((x) => x.path === t.path) ?? t)
          return (
            <box class="bt-transfer" spacing={8}>
              <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={4}>
                <label label={live(transferLabel)} halign={Gtk.Align.START} ellipsize={2} maxWidthChars={34} />
                <levelbar value={live((x) => (x.size ? x.transferred / x.size : 0))} />
              </box>
              <button class="bt-icon-btn" tooltipText="Cancel" valign={Gtk.Align.CENTER}
                onClicked={() => cancelTransfer(t.path)}>
                <image iconName="window-close-symbolic" pixelSize={12} />
              </button>
            </box>
          )
        }}
      </For>
    </box>
  )
}

function Options() {
  const [open, setOpen] = createState(false)
  const opt = (key: keyof Omit<BtSettings, "autoConnect">, label: string) => (
    <box class="bt-toggle" spacing={8}>
      <label label={label} hexpand halign={Gtk.Align.START} />
      <switch
        class="net-switch"
        valign={Gtk.Align.CENTER}
        active={settings((s) => s[key])}
        $={(self) =>
          self.connect("notify::active", () => {
            if (self.active !== settings.get()[key]) updateSettings({ [key]: self.active })
          })
        }
      />
    </box>
  )

  return (
    <box orientation={Gtk.Orientation.VERTICAL}>
      <button class="net-settings" onClicked={() => setOpen(!open.get())}>
        <box>
          <label label="Options" halign={Gtk.Align.START} hexpand />
          <image iconName={open((o) => (o ? "pan-up-symbolic" : "pan-down-symbolic"))} pixelSize={14} />
        </box>
      </button>
      <revealer revealChild={open} transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN} transitionDuration={180}>
        <box class="bt-options" orientation={Gtk.Orientation.VERTICAL} spacing={4}>
          {opt("notifyConnections", "Connection notifications")}
          {opt("notifyLowBattery", "Low battery warnings")}
          {opt("controllerWakelock", "Stay awake with game controller")}
          {opt("acceptFromTrusted", "Auto-accept files from trusted devices")}
          {opt("showUnnamed", "Show unnamed devices")}
        </box>
      </revealer>
    </box>
  )
}
