import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createExternal, For, With } from "ags"
import NM from "gi://NM"
import { InfoPanel } from "./InfoPanel"
import { connectAndWait } from "./connections"
import { createRowOps, type Expanded } from "./NetRow"
import {
  activeFor, client, connectAll, connectivityText, deactivate, deviceName, deviceStateText, deviceTypeIcon,
  disconnectDevice, isVpnLike, openEditor,
} from "./util"

// Wired / mobile broadband / Bluetooth PAN+DUN devices and VPN + WireGuard
// connections (nm-applet's per-device menus and "VPN Connections").

const isOtherDevice = (d: NM.Device) =>
  !(d instanceof NM.DeviceVeth) && (d instanceof NM.DeviceEthernet || d instanceof NM.DeviceModem || d instanceof NM.DeviceBt)

// Devices of the given kind, kept in sync with hotplug.
export function createDevices<T extends NM.Device>(pred: (d: NM.Device) => boolean) {
  const list = () => client.get_devices().filter((d) => pred(d) && d.get_managed() !== false) as T[]
  return createExternal<T[]>(list(), (set) =>
    connectAll(client, ["device-added", "device-removed"], () => set(list())))
}

function DeviceCard({ dev, expanded }: { dev: NM.Device; expanded: Expanded }) {
  const [open, setOpen] = expanded
  const key = dev.get_path()
  const isOpen = open((k) => k === key)
  const toggle = () => setOpen(open.get() === key ? null : key)
  const state = createBinding(dev, "state")
  const ac = createBinding(dev, "activeConnection")
  const available = createBinding(dev, "availableConnections")
  const connectivity = createBinding(client, "connectivity")
  const ops = createRowOps()

  const activated = state((s) => s === NM.DeviceState.ACTIVATED)
  const status = createComputed(() => {
    const s = state()
    const working = deviceStateText(s)
    if (working) return working
    if (ops.busy()) return ops.busy()!
    if (ops.error()) return ops.error()!
    if (s === NM.DeviceState.UNAVAILABLE)
      return dev instanceof NM.DeviceEthernet ? "Cable unplugged" : dev.get_firmware_missing() ? "Firmware missing" : "Unavailable"
    if (s === NM.DeviceState.UNMANAGED) return "Not managed"
    if (s === NM.DeviceState.ACTIVATED) {
      const c = ac()?.get_id() ?? "Connected"
      const extra = ac() === client.get_primary_connection() ? connectivityText(connectivity()) : null
      return extra ? `${c} · ${extra}` : c
    }
    return "Disconnected"
  })

  const connect = (conn: NM.Connection | null = null) =>
    ops.run("Connecting…", () => connectAndWait({ conn, device: dev, removeOnFailure: false }))

  const usable = state((s) => s >= NM.DeviceState.DISCONNECTED)

  return (
    <box class="bt-device" orientation={Gtk.Orientation.VERTICAL}>
      <box class={createComputed(() =>
        ["net-row", "bt-row", activated() && "active", ops.error() && "error", isOpen() && "open"].filter(Boolean).join(" "))}>
        <button class="bt-row-main" hexpand sensitive={usable}
          onClicked={() => (activated.get() ? toggle() : void connect())}>
          <box spacing={10}>
            <image iconName={deviceTypeIcon(dev)} pixelSize={17} />
            <box orientation={Gtk.Orientation.VERTICAL} hexpand valign={Gtk.Align.CENTER}>
              <label class="bt-name" label={deviceName(dev)} halign={Gtk.Align.START} ellipsize={3} maxWidthChars={26} />
              <label class={ops.error((e) => `bt-status${e ? " error" : ""}`)} label={status}
                halign={Gtk.Align.START} ellipsize={3} maxWidthChars={34} />
            </box>
            <Gtk.Spinner visible={state((s) => deviceStateText(s) !== null)}
              $={(self) => self.connect("map", () => self.start())} />
          </box>
        </button>
        <button class="bt-expand" valign={Gtk.Align.CENTER} tooltipText="Details" onClicked={toggle}>
          <image iconName={isOpen((o) => (o ? "pan-up-symbolic" : "pan-down-symbolic"))} pixelSize={14} />
        </button>
      </box>

      <revealer revealChild={isOpen} transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN} transitionDuration={180}>
        <With value={isOpen}>
          {(o) =>
            o ? (
              <box class="bt-panel" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
                <With value={ac}>{(a) => (a && activated.get() ? <InfoPanel ac={a} /> : <box />)}</With>

                <box orientation={Gtk.Orientation.VERTICAL} spacing={4} visible={available((l) => l.length > 0)}>
                  <label class="net-section-title" label="Connections" halign={Gtk.Align.START} />
                  <For each={available}>
                    {(c: NM.RemoteConnection) => (
                      <button class="bt-option" onClicked={() => void connect(c)}>
                        <box spacing={8}>
                          <label label={c.get_id()} hexpand halign={Gtk.Align.START} ellipsize={3} />
                          <image class="net-check" iconName="object-select-symbolic" pixelSize={12}
                            visible={ac((a) => a?.get_uuid() === c.get_uuid())} />
                        </box>
                      </button>
                    )}
                  </For>
                </box>

                <box class="bt-actions" spacing={6} homogeneous>
                  <button class="bt-action" visible={activated}
                    onClicked={() => void ops.run("Disconnecting…", () => disconnectDevice(dev))}>
                    <label label="Disconnect" />
                  </button>
                  <button class="bt-action" visible={createComputed(() => !activated() && usable())}
                    onClicked={() => void connect()}>
                    <label label="Connect" />
                  </button>
                  <button class="bt-action" visible={ac((a) => !!a)}
                    onClicked={() => { const u = ac.get()?.get_uuid(); if (u) openEditor(["--edit", u]) }}>
                    <label label="Edit…" />
                  </button>
                </box>
              </box>
            ) : (
              <box />
            )
          }
        </With>
      </revealer>
    </box>
  )
}

export function DevicesSection({ expanded }: { expanded: Expanded }) {
  const devices = createDevices<NM.Device>(isOtherDevice)
  const title = devices((l) =>
    l.every((d) => d instanceof NM.DeviceEthernet) ? "Wired" : l.length > 1 ? "Devices" : "Device")
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={6} visible={devices((l) => l.length > 0)}>
      <label class="net-section-title" label={title} halign={Gtk.Align.START} />
      <For each={devices}>{(d: NM.Device) => <DeviceCard dev={d} expanded={expanded} />}</For>
    </box>
  )
}

// ---- VPN -------------------------------------------------------------------------

function VpnRow({ conn, expanded }: { conn: NM.RemoteConnection; expanded: Expanded }) {
  const [open, setOpen] = expanded
  const key = conn.get_uuid()
  const isOpen = open((k) => k === key)
  const ops = createRowOps()

  // the matching active connection and its state, live
  const ac = createExternal<NM.ActiveConnection | null>(activeFor(conn), (set) =>
    connectAll(client, ["notify::active-connections"], () => set(activeFor(conn))))
  const acState = createComputed(() => {
    const a = ac()
    return a ? createBinding(a, "state")() : NM.ActiveConnectionState.DEACTIVATED
  })
  const on = acState(
    (s) => s === NM.ActiveConnectionState.ACTIVATING || s === NM.ActiveConnectionState.ACTIVATED)

  const status = createComputed(() => {
    const s = acState()
    if (s === NM.ActiveConnectionState.ACTIVATING) return "Connecting…"
    if (s === NM.ActiveConnectionState.DEACTIVATING) return "Disconnecting…"
    if (s === NM.ActiveConnectionState.ACTIVATED) return "Connected"
    return ops.error() ?? ops.busy() ?? (conn.get_connection_type() === "wireguard" ? "WireGuard" : "VPN")
  })

  const setOn = (v: boolean) => {
    const a = ac.get()
    if (v && !a) void ops.run("Connecting…", () => connectAndWait({ conn, device: null, removeOnFailure: false }))
    if (!v && a) void ops.run("Disconnecting…", () => deactivate(a))
  }

  return (
    <box class="bt-device" orientation={Gtk.Orientation.VERTICAL}>
      <box class={createComputed(() =>
        ["net-row", "bt-row", acState() === NM.ActiveConnectionState.ACTIVATED && "active", ops.error() && "error",
          isOpen() && "open"].filter(Boolean).join(" "))}>
        <button class="bt-row-main" hexpand onClicked={() => setOpen(open.get() === key ? null : key)}>
          <box spacing={10}>
            <image iconName="network-vpn-symbolic" pixelSize={17} />
            <box orientation={Gtk.Orientation.VERTICAL} hexpand valign={Gtk.Align.CENTER}>
              <label class="bt-name" label={conn.get_id()} halign={Gtk.Align.START} ellipsize={3} maxWidthChars={26} />
              <label class={ops.error((e) => `bt-status${e ? " error" : ""}`)} label={status}
                halign={Gtk.Align.START} ellipsize={3} maxWidthChars={34} />
            </box>
            <Gtk.Spinner visible={acState((s) => s === NM.ActiveConnectionState.ACTIVATING)}
              $={(self) => self.connect("map", () => self.start())} />
          </box>
        </button>
        <switch class="net-switch" valign={Gtk.Align.CENTER} active={on}
          $={(self) => self.connect("notify::active", () => self.active !== on.get() && setOn(self.active))} />
      </box>
      <revealer revealChild={isOpen} transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN} transitionDuration={180}>
        <With value={isOpen}>
          {(o) =>
            o ? (
              <box class="bt-panel" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
                <With value={ac}>{(a) => (a ? <InfoPanel ac={a} /> : <box />)}</With>
                <box class="bt-actions" spacing={6} homogeneous>
                  <button class="bt-action" onClicked={() => openEditor(["--edit", conn.get_uuid()])}>
                    <label label="Edit…" />
                  </button>
                </box>
              </box>
            ) : (
              <box />
            )
          }
        </With>
      </revealer>
    </box>
  )
}

export function VpnSection({ expanded }: { expanded: Expanded }) {
  const list = () =>
    client
      .get_connections()
      .filter(isVpnLike)
      .sort((a, b) => (a.get_id() ?? "").localeCompare(b.get_id() ?? ""))
  const vpns = createExternal<NM.RemoteConnection[]>(list(), (set) =>
    connectAll(client, ["connection-added", "connection-removed"], () => set(list())))
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <box spacing={6}>
        <label class="net-section-title" label="VPN" halign={Gtk.Align.START} hexpand />
        <button class="bt-icon-btn" tooltipText="Add a VPN connection…" valign={Gtk.Align.CENTER}
          onClicked={() => openEditor(["--create", "--type", "vpn"])}>
          <image iconName="list-add-symbolic" pixelSize={14} />
        </button>
        <button class="bt-icon-btn" tooltipText="Configure VPN…" valign={Gtk.Align.CENTER}
          onClicked={() => openEditor(["--show", "--type", "vpn"])}>
          <image iconName="emblem-system-symbolic" pixelSize={14} />
        </button>
      </box>
      <label class="net-empty-small" label="No VPN connections configured" halign={Gtk.Align.START}
        visible={vpns((l) => l.length === 0)} />
      <For each={vpns}>{(c: NM.RemoteConnection) => <VpnRow conn={c} expanded={expanded} />}</For>
    </box>
  )
}
