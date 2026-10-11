import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createState, For, With, onCleanup, type Accessor } from "ags"
import NM from "gi://NM"
import { InfoPanel } from "./InfoPanel"
import { createWifiModel, type WifiNet, type WifiSections } from "./model"
import { NetRow, createRowOps } from "./NetRow"
import { deactivate, deviceName, isHotspot, ssidText, unusableText } from "./util"

// One Wi-Fi adapter: unusable-state message, running hotspot, and the
// Connected / Saved / Other network lists.

function HotspotCard({ ac }: { ac: NM.ActiveConnection }) {
  const ops = createRowOps()
  const [open, setOpen] = createState(false)
  const ssid = ssidText(ac.get_connection()?.get_setting_wireless()?.get_ssid() ?? null)
  return (
    <box class="bt-device" orientation={Gtk.Orientation.VERTICAL}>
      <box class={open((o) => `net-row bt-row active${o ? " open" : ""}`)}>
        <button class="bt-row-main" hexpand onClicked={() => setOpen(!open.get())}>
          <box spacing={10}>
            <image iconName="network-wireless-hotspot-symbolic" pixelSize={17} />
            <box orientation={Gtk.Orientation.VERTICAL} hexpand valign={Gtk.Align.CENTER}>
              <label class="bt-name" label={ssid || "Hotspot"} halign={Gtk.Align.START} ellipsize={3} />
              <label class="bt-status" label={createComputed(() => ops.error() ?? ops.busy() ?? "Hotspot active")}
                halign={Gtk.Align.START} />
            </box>
          </box>
        </button>
        <button class="bt-action" valign={Gtk.Align.CENTER} onClicked={() => void ops.run("Stopping…", () => deactivate(ac))}>
          <label label="Stop" />
        </button>
      </box>
      <revealer revealChild={open} transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN} transitionDuration={180}>
        <box class="bt-panel">
          <InfoPanel ac={ac} />
        </box>
      </revealer>
    </box>
  )
}

export function WifiSection({ dev, showName, scanning }: {
  dev: NM.DeviceWifi
  showName: Accessor<boolean>
  scanning: Accessor<boolean>
}) {
  const model = createWifiModel(dev)
  const sections = model.sections
  const expanded = createState<string | null>(null)
  const [openKey] = expanded
  const state = createBinding(dev, "state")
  const unusable = state(() => unusableText(dev))
  const activeAc = createBinding(dev, "activeConnection")
  const hotspot = activeAc((ac) => (ac && isHotspot(ac.get_connection()) ? ac : null))

  // keep the order stable while the pointer is over the list or a row is open
  let hovering = false
  const syncFrozen = () => model.setFrozen(hovering || openKey.get() !== null)
  const unsub = openKey.subscribe(syncFrozen)
  onCleanup(unsub)

  const Section = ({ title, list }: { title: string; list: (s: WifiSections) => WifiNet[] }) => {
    const items = sections(list)
    return (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={6} visible={items((l) => l.length > 0)}>
        <label class="net-section-title" label={title} halign={Gtk.Align.START} />
        <For each={items}>
          {(n: WifiNet) => <NetRow net={n} expanded={expanded} active={title === "Connected"} />}
        </For>
      </box>
    )
  }

  const empty = sections((s) => !s.active && !s.saved.length && !s.other.length)

  return (
    <box class="net-wifi-device" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <label class="net-device-title" label={deviceName(dev)} halign={Gtk.Align.START} visible={showName}
        ellipsize={3} />
      <label class="bt-banner net-unusable" wrap xalign={0} visible={unusable((u) => !!u)}
        label={unusable((u) => u ?? "")} />

      <With value={hotspot}>{(ac) => (ac ? <HotspotCard ac={ac} /> : <box visible={false} />)}</With>

      <box visible={createComputed(() => !unusable() && !hotspot())}>
        <box
          class="net-list"
          hexpand
          orientation={Gtk.Orientation.VERTICAL}
          spacing={6}
          $={(self) => {
            const motion = new Gtk.EventControllerMotion()
            motion.connect("enter", () => ((hovering = true), syncFrozen()))
            motion.connect("leave", () => ((hovering = false), syncFrozen()))
            self.add_controller(motion)
          }}
        >
          <label class="net-empty" visible={empty}
            label={scanning((s) => (s ? "Searching for networks…" : "No networks found"))} />
          <Section title="Connected" list={(s) => (s.active ? [s.active] : [])} />
          <Section title="Saved Networks" list={(s) => s.saved} />
          <Section title="Other Networks" list={(s) => s.other} />
        </box>
      </box>
    </box>
  )
}
