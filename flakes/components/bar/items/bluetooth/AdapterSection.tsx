import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createState, With, onCleanup } from "ags"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth"

// Adapter controls under the header: adapter picker (multi-adapter setups),
// visible name, and a discoverable toggle with countdown (DiscvManager).
export function AdapterSection() {
  const bt = AstalBluetooth.get_default()
  const adapters = createBinding(bt, "adapters")
  const def = createBinding(bt, "adapter")
  const [picked, setPicked] = createState<string | null>(null) // address

  const adapter = createComputed(() => {
    const list = adapters()
    return list.find((a) => a.address === picked()) ?? def() ?? list[0] ?? null
  })

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <box class="bt-adapters" spacing={6} visible={adapters((l) => l.length > 1)}>
        <With value={adapters}>
          {(list) => (
            <box spacing={6}>
              {list.map((a) => (
                <button
                  class={adapter((cur) => `bt-chip${cur === a ? " active" : ""}`)}
                  onClicked={() => setPicked(a.address)}
                >
                  <label label={a.alias || a.name || a.address} />
                </button>
              ))}
            </box>
          )}
        </With>
      </box>
      <With value={adapter}>
        {(a) => (a ? <AdapterControls adapter={a} /> : <box />)}
      </With>
    </box>
  )
}

function AdapterControls({ adapter }: { adapter: AstalBluetooth.Adapter }) {
  const discoverable = createBinding(adapter, "discoverable")
  const timeout = createBinding(adapter, "discoverableTimeout")
  const [remaining, setRemaining] = createState(0)

  // local countdown; BlueZ flips Discoverable back off when it expires
  let timer = 0
  const stop = () => {
    if (timer) GLib.source_remove(timer)
    timer = 0
  }
  const sync = () => {
    stop()
    if (!adapter.discoverable || adapter.discoverableTimeout === 0) return setRemaining(0)
    setRemaining(adapter.discoverableTimeout)
    timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
      const left = remaining.get() - 1
      setRemaining(Math.max(left, 0))
      if (left > 0) return GLib.SOURCE_CONTINUE
      timer = 0
      return GLib.SOURCE_REMOVE
    })
  }
  const h = adapter.connect("notify::discoverable", sync)
  sync()
  onCleanup(() => {
    stop()
    adapter.disconnect(h)
  })

  const hint = createComputed(() => {
    if (!discoverable()) return `Visible to others as “${adapter.alias || adapter.name}”`
    const r = remaining()
    if (timeout() === 0 || r === 0) return "Visible to nearby devices"
    return `Visible for ${Math.floor(r / 60)}:${String(r % 60).padStart(2, "0")}`
  })

  return (
    <box class="bt-toggle bt-discoverable" spacing={8}>
      <box orientation={Gtk.Orientation.VERTICAL} hexpand>
        <label label="Discoverable" halign={Gtk.Align.START} />
        <label class="bt-hint" label={hint} halign={Gtk.Align.START} ellipsize={3} maxWidthChars={34} />
      </box>
      <switch
        class="net-switch"
        valign={Gtk.Align.CENTER}
        active={discoverable}
        $={(self) =>
          self.connect("notify::active", () => {
            if (self.active === adapter.discoverable) return
            try {
              // incoming pairing needs Pairable too (often off by default)
              if (self.active) adapter.pairable = true
              adapter.discoverable = self.active
            } catch (e) {
              console.error("bluetooth: discoverable:", e)
              self.active = adapter.discoverable
            }
          })
        }
      />
    </box>
  )
}
