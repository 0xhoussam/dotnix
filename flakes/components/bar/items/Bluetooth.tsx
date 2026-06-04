import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, For } from "ags"
import { execAsync } from "ags/process"
import AstalBluetooth from "gi://AstalBluetooth"

// Bluetooth indicator + popover (mirrors the Wi-Fi one): power toggle and a
// list of devices; click to connect/disconnect.
export function Bluetooth() {
  const bt = AstalBluetooth.get_default()

  const powered = createBinding(bt, "isPowered")
  const connected = createBinding(bt, "isConnected")
  const devices = createBinding(bt, "devices")

  const barIcon = createComputed(() =>
    !powered()
      ? "bluetooth-disabled-symbolic"
      : connected()
        ? "bluetooth-active-symbolic"
        : "bluetooth-symbolic",
  )

  // Named devices: connected first, then paired, then by name.
  const list = createComputed(() =>
    devices()
      .filter((d) => d.name)
      .sort((a, b) => {
        const rank = (d: AstalBluetooth.Device) => (d.connected ? 0 : d.paired ? 1 : 2)
        return rank(a) - rank(b) || a.name.localeCompare(b.name)
      })
      .slice(0, 20),
  )

  const startScan = () => {
    try {
      bt.adapter?.start_discovery()
    } catch {
      // adapter off / busy
    }
  }

  return (
    <menubutton class="bluetooth">
      <image iconName={barIcon} pixelSize={16} />
      <popover
        class="net-popover"
        $={(self) =>
          self.connect("notify::visible", () => {
            if (self.visible && bt.isPowered) startScan()
          })
        }
      >
        <box class="net-panel" orientation={Gtk.Orientation.VERTICAL}>
          <box class="net-header">
            <label label="Bluetooth" hexpand halign={Gtk.Align.START} />
            <switch
              class="net-switch"
              active={powered}
              $={(self) =>
                self.connect("notify::active", () => {
                  if (self.active !== bt.isPowered) {
                    bt.adapter?.set_powered(self.active)
                    if (self.active) startScan()
                  }
                })
              }
            />
          </box>

          <box class="net-body" orientation={Gtk.Orientation.VERTICAL} visible={powered}>
            <label class="net-section-title" label="Devices" halign={Gtk.Align.START} />
            <Gtk.ScrolledWindow heightRequest={280} hscrollbarPolicy={Gtk.PolicyType.NEVER}>
              <box class="net-list" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
                <label
                  class="net-empty"
                  label="Searching…"
                  visible={list((l) => l.length === 0)}
                />
                <For each={list}>
                  {(d: AstalBluetooth.Device) => <BtRow device={d} />}
                </For>
              </box>
            </Gtk.ScrolledWindow>
          </box>

          <button
            class="net-settings"
            onClicked={() => execAsync(["blueman-manager"]).catch(() => {})}
          >
            <label label="Bluetooth Settings…" halign={Gtk.Align.START} hexpand />
          </button>
        </box>
      </popover>
    </menubutton>
  )
}

function BtRow({ device }: { device: AstalBluetooth.Device }) {
  const connected = createBinding(device, "connected")
  const connecting = createBinding(device, "connecting")
  const battery = createBinding(device, "batteryPercentage")

  const toggle = () => {
    if (device.connected) device.disconnect_device(() => {})
    else device.connect_device(() => {})
  }

  return (
    <button class={connected((c) => `net-row${c ? " active" : ""}`)} onClicked={toggle}>
      <box spacing={10}>
        <image iconName={device.icon || "bluetooth-symbolic"} pixelSize={17} />
        <label label={device.name} hexpand halign={Gtk.Align.START} ellipsize={3} maxWidthChars={20} />
        <label
          class="bt-battery"
          label={battery((b) => (b > 0 ? `${Math.round(b * 100)}%` : ""))}
          visible={battery((b) => b > 0)}
        />
        <Gtk.Spinner visible={connecting} $={(self) => self.connect("map", () => self.start())} />
        {/* connected check */}
        <image class="net-check" iconName="object-select-symbolic" pixelSize={14} visible={connected} />
      </box>
    </button>
  )
}
