import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createExternal, createState, For, type Accessor } from "ags"
import GLib from "gi://GLib"
import NM from "gi://NM"
import { setJoinRequest, joinRequest } from "./connections"
import { DevicesSection, VpnSection, createDevices } from "./OtherSections"
import { currentSecret } from "./prompts"
import { portalUri } from "./services"
import { WifiSection } from "./WifiSection"
import {
  client, connectAll, connectivityText, isHotspot, openEditor, openUri, requestScan, setNetworkingEnabled,
  setWifiEnabled, setWwanEnabled, settings, ssidText, strengthIcon, updateSettings, type NetSettings,
} from "./util"

// Network indicator + popover with nm-applet's feature set: Wi-Fi (per
// adapter) with saved/other networks, hidden networks and hotspot, wired /
// mobile / Bluetooth devices, VPN, connection information, notifications.

const isVpnAc = (ac: NM.ActiveConnection) => ac instanceof NM.VpnConnection || ac.get_connection_type() === "wireguard"
// NM >= 1.42 reports "lo" as an active connection; it's never interesting here.
const visibleAcs = () => client.get_active_connections().filter((a) => a.get_connection_type() !== "loopback")

// Bumps whenever anything the bar icon / tooltip depends on changes.
function createNmTick(): Accessor<number> {
  return createExternal(0, (set) => {
    let n = 0
    const bump = () => set(++n)
    let devOffs: (() => void)[] = []
    const watchDevices = () => {
      devOffs.forEach((f) => f())
      devOffs = client.get_devices().map((d) => {
        let apOff = () => {}
        const watchAp = () => {
          apOff()
          const ap = d instanceof NM.DeviceWifi ? d.get_active_access_point() : null
          apOff = ap ? connectAll(ap, ["notify::strength"], bump) : () => {}
        }
        watchAp()
        const off = connectAll(d, ["state-changed", "notify::active-access-point"], () => (watchAp(), bump()))
        return () => (off(), apOff())
      })
    }
    watchDevices()
    const offClient = connectAll(client, [
      "notify::primary-connection", "notify::activating-connection", "notify::connectivity", "notify::state",
      "notify::networking-enabled", "notify::nm-running", "notify::wireless-enabled",
      "notify::wireless-hardware-enabled", "notify::active-connections",
    ], bump)
    const offDevs = connectAll(client, ["device-added", "device-removed"], () => (watchDevices(), bump()))
    return () => {
      offClient()
      offDevs()
      devOffs.forEach((f) => f())
    }
  })
}

function mainConnection(): NM.ActiveConnection | null {
  const all = visibleAcs()
  const primary = client.get_primary_connection()
  if (primary && !isVpnAc(primary)) return primary
  // VPN primary / hotspot (no default route): show the underlying device
  return client.get_activating_connection() ?? all.find((a) => !isVpnAc(a) && a.get_devices().length > 0) ?? null
}

function barIcon(): string {
  if (!client.get_nm_running()) return "network-error-symbolic"
  if (!client.networking_get_enabled()) return "network-offline-symbolic"
  const ac = mainConnection()
  const hasWifi = client.get_devices().some((d) => d instanceof NM.DeviceWifi)
  if (!ac) {
    if (!hasWifi) return "network-wired-disconnected-symbolic"
    return client.wireless_get_enabled() ? "network-wireless-offline-symbolic" : "network-wireless-disabled-symbolic"
  }
  const dev = ac.get_devices()[0] ?? null
  const activating = ac.get_state() === NM.ActiveConnectionState.ACTIVATING
  const c = client.get_connectivity()
  const limited = ac === client.get_primary_connection() &&
    (c === NM.ConnectivityState.PORTAL || c === NM.ConnectivityState.LIMITED || c === NM.ConnectivityState.NONE)

  if (dev instanceof NM.DeviceWifi) {
    if (activating) return "network-wireless-acquiring-symbolic"
    if (isHotspot(ac.get_connection())) return "network-wireless-hotspot-symbolic"
    if (limited) return "network-wireless-no-route-symbolic"
    return strengthIcon(dev.get_active_access_point()?.get_strength() ?? 0)
  }
  if (dev instanceof NM.DeviceModem) {
    if (activating) return "network-cellular-acquiring-symbolic"
    return limited ? "network-cellular-no-route-symbolic" : "network-cellular-connected-symbolic"
  }
  if (dev instanceof NM.DeviceBt) return "bluetooth-active-symbolic"
  if (activating) return "network-wired-acquiring-symbolic"
  return limited ? "network-wired-no-route-symbolic" : "network-wired-symbolic"
}

// nm-applet's tooltip strings, one line per active connection.
function tooltipLine(ac: NM.ActiveConnection): string {
  const id = ac.get_id()
  const st = ac.get_state()
  if (isVpnAc(ac)) {
    if (st === NM.ActiveConnectionState.ACTIVATING) return `Starting VPN connection “${id}”…`
    return st === NM.ActiveConnectionState.ACTIVATED ? `VPN connection “${id}” active` : ""
  }
  const dev = ac.get_devices()[0]
  if (st === NM.ActiveConnectionState.ACTIVATING && dev) {
    switch (dev.get_state()) {
      case NM.DeviceState.NEED_AUTH:
        return `User authentication required for network connection “${id}”…`
      case NM.DeviceState.IP_CONFIG:
      case NM.DeviceState.IP_CHECK:
        return `Requesting a network address for “${id}”…`
      default:
        return `Preparing network connection “${id}”…`
    }
  }
  if (st !== NM.ActiveConnectionState.ACTIVATED) return ""
  const conn = ac.get_connection()
  let line = `Network connection “${id}” active`
  if (dev instanceof NM.DeviceWifi) {
    const ap = dev.get_active_access_point()
    line = isHotspot(conn)
      ? `Hotspot “${ssidText(conn?.get_setting_wireless()?.get_ssid() ?? null)}” active`
      : `Wi-Fi network connection “${id}” active${ap ? `: ${ssidText(ap.get_ssid())} (${ap.get_strength()}%)` : ""}`
  }
  if (ac === client.get_primary_connection()) {
    const c = connectivityText(client.get_connectivity())
    if (c) line += ` — ${c}`
  }
  return line
}

function tooltipText(): string {
  if (!client.get_nm_running()) return "NetworkManager is not running"
  if (!client.networking_get_enabled()) return "Networking disabled"
  const lines = visibleAcs().map(tooltipLine).filter(Boolean)
  return lines.length ? lines.join("\n") : "No network connection"
}

export function Network() {
  const tick = createNmTick()
  const icon = tick(barIcon)
  const tooltip = tick(tooltipText)
  const vpnActive = tick(() =>
    visibleAcs().some((a) => isVpnAc(a) && a.get_state() === NM.ActiveConnectionState.ACTIVATED))

  const nmRunning = createBinding(client, "nmRunning")
  const networking = createBinding(client, "networkingEnabled")
  const wifiEnabled = createBinding(client, "wirelessEnabled")
  const wifiHw = createBinding(client, "wirelessHardwareEnabled")
  const connectivity = createBinding(client, "connectivity")
  const wifiDevices = createDevices<NM.DeviceWifi>((d) => d instanceof NM.DeviceWifi)
  const hasWifi = wifiDevices((l) => l.length > 0)
  const ready = createComputed(() => nmRunning() && networking())
  const expanded = createState<string | null>(null)

  // ---- scanning ----
  const [scanning, setScanning] = createState(false)
  let scanTimer = 0
  const scan = () => {
    if (!client.wireless_get_enabled()) return
    const devs = wifiDevices.get()
    if (!devs.length) return
    setScanning(true)
    devs.forEach((d) => void requestScan(d))
    if (scanTimer) GLib.source_remove(scanTimer)
    scanTimer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 10, () => {
      setScanning(false)
      scanTimer = 0
      return GLib.SOURCE_REMOVE
    })
  }

  let popover: Gtk.Popover | null = null
  // our dialogs need the keyboard: get the popover out of the way
  currentSecret.subscribe(() => currentSecret.get() && popover?.popdown())
  joinRequest.subscribe(() => joinRequest.get() && popover?.popdown())

  const openJoin = (kind: "hidden" | "hotspot") => {
    const dev = wifiDevices.get()[0] ?? null
    if (kind === "hotspot") {
      if (dev) setJoinRequest({ kind: "hotspot", device: dev })
    } else setJoinRequest({ kind: "wifi", device: dev, form: { hidden: true }, lockSsid: false })
  }

  const banner = createComputed(() => {
    if (!nmRunning()) return "NetworkManager is not running."
    if (!networking()) return "Networking is disabled."
    if (hasWifi() && !wifiHw()) return "Wi-Fi is disabled by a hardware switch or airplane mode."
    return null
  })

  return (
    <menubutton class="network" tooltipText={tooltip}>
      <box spacing={2}>
        <image iconName={icon} pixelSize={16} />
        <image class="net-vpn-badge" iconName="network-vpn-symbolic" pixelSize={11} visible={vpnActive}
          valign={Gtk.Align.END} />
      </box>
      <popover
        class="net-popover bt-popover"
        $={(self) => {
          popover = self
          self.connect("notify::visible", () => {
            if (self.visible) scan()
          })
        }}
      >
        <box class="net-panel" orientation={Gtk.Orientation.VERTICAL}>
          <box class="net-header" spacing={6}>
            <label label={hasWifi((w) => (w ? "Wi-Fi" : "Network"))} hexpand halign={Gtk.Align.START} />
            <Gtk.Spinner visible={createComputed(() => scanning() && wifiEnabled())}
              $={(self) => self.connect("map", () => self.start())} />
            <button class="bt-icon-btn" tooltipText="Scan again" onClicked={scan}
              visible={createComputed(() => hasWifi() && wifiEnabled() && !scanning() && ready())}>
              <image iconName="view-refresh-symbolic" pixelSize={14} />
            </button>
            <switch
              class="net-switch"
              valign={Gtk.Align.CENTER}
              visible={hasWifi}
              active={wifiEnabled}
              sensitive={createComputed(() => wifiHw() && ready())}
              $={(self) =>
                self.connect("notify::active", () => {
                  if (self.active !== client.wireless_get_enabled())
                    setWifiEnabled(self.active).catch((e) => {
                      console.error("network: toggle Wi-Fi:", e)
                      self.active = client.wireless_get_enabled()
                    })
                })
              }
            />
          </box>

          <box class="bt-banner" spacing={8} visible={banner((b) => !!b)}>
            <label label={banner((b) => b ?? "")} wrap xalign={0} hexpand />
            <button class="bt-chip" valign={Gtk.Align.CENTER} visible={createComputed(() => nmRunning() && !networking())}
              onClicked={() => setNetworkingEnabled(true).catch((e) => console.error("network: enable:", e))}>
              <label label="Enable" />
            </button>
          </box>

          <box class="net-portal" spacing={8} visible={connectivity((c) => c === NM.ConnectivityState.PORTAL)}>
            <image iconName="network-wireless-no-route-symbolic" pixelSize={16} />
            <label label="This network requires you to sign in." wrap xalign={0} hexpand />
            <button class="bt-chip" valign={Gtk.Align.CENTER} onClicked={() => openUri(portalUri())}>
              <label label="Sign In" />
            </button>
          </box>

          <Gtk.ScrolledWindow class="net-scroll" propagateNaturalHeight maxContentHeight={620}
            hscrollbarPolicy={Gtk.PolicyType.NEVER} visible={ready}>
            <box class="net-body" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
              <box orientation={Gtk.Orientation.VERTICAL} spacing={8} visible={createComputed(() => hasWifi() && wifiEnabled())}>
                <For each={wifiDevices}>
                  {(d: NM.DeviceWifi) => (
                    <WifiSection dev={d} scanning={scanning} showName={wifiDevices((l) => l.length > 1)} />
                  )}
                </For>
                <box class="net-wifi-actions" spacing={6} homogeneous>
                  <button class="bt-action" onClicked={() => openJoin("hidden")}>
                    <label label="Hidden Network…" />
                  </button>
                  <button class="bt-action" onClicked={() => openJoin("hotspot")}>
                    <label label="Hotspot…" />
                  </button>
                </box>
              </box>

              <DevicesSection expanded={expanded} />
              <VpnSection expanded={expanded} />
            </box>
          </Gtk.ScrolledWindow>

          <Options />

          <button class="net-settings" onClicked={() => (popover?.popdown(), openEditor())}>
            <label label="Network Settings…" halign={Gtk.Align.START} hexpand />
          </button>
        </box>
      </popover>
    </menubutton>
  )
}

function Options() {
  const [open, setOpen] = createState(false)
  const networking = createBinding(client, "networkingEnabled")
  const wwan = createBinding(client, "wwanEnabled")
  const wwanHw = createBinding(client, "wwanHardwareEnabled")
  const modems = createDevices<NM.DeviceModem>((d) => d instanceof NM.DeviceModem)

  const Toggle = ({ label, active, onToggle, visible = true, sensitive = true }: {
    label: string
    active: Accessor<boolean>
    onToggle: (v: boolean) => void
    visible?: Accessor<boolean> | boolean
    sensitive?: Accessor<boolean> | boolean
  }) => (
    <box class="bt-toggle" spacing={8} visible={visible}>
      <label label={label} hexpand halign={Gtk.Align.START} />
      <switch class="net-switch" valign={Gtk.Align.CENTER} active={active} sensitive={sensitive}
        $={(self) => self.connect("notify::active", () => self.active !== active.get() && onToggle(self.active))} />
    </box>
  )

  const opt = (key: keyof NetSettings, label: string) => (
    <Toggle label={label} active={settings((s) => s[key])} onToggle={(v) => updateSettings({ [key]: v })} />
  )

  const fail = (what: string) => (e: unknown) => console.error(`network: ${what}:`, e)

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
          <Toggle label="Enable networking" active={networking}
            onToggle={(v) => void setNetworkingEnabled(v).catch(fail("networking"))} />
          <Toggle label="Enable mobile broadband" active={wwan} sensitive={wwanHw}
            visible={modems((m) => m.length > 0)} onToggle={(v) => void setWwanEnabled(v).catch(fail("wwan"))} />
          {opt("notifyConnected", "Connection notifications")}
          {opt("notifyDisconnected", "Disconnect / failure notifications")}
          {opt("notifyVpn", "VPN notifications")}
          {opt("notifyAvailable", "“Networks available” notifications")}
        </box>
      </revealer>
    </box>
  )
}

