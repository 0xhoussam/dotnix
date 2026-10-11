import { Gtk } from "ags/gtk4"
import { createExternal, createState, For, With } from "ags"
import { execAsync } from "ags/process"
import NM from "gi://NM"
import {
  SECURITY_LABEL, apSecurity, client, connectAll, connectivityText, deviceName, formatSpeed, getSecrets, isHotspot,
  ssidText,
} from "./util"

// "Connection Information" (nm-applet applet-dialogs.c): general, IPv4,
// IPv6, hotspot and VPN details for one active connection.

interface InfoGroup {
  title: string
  rows: [string, string][]
}

function ip4ToInt(s: string) {
  return s.split(".").reduce((acc, o) => (acc << 8) + (parseInt(o, 10) & 255), 0) >>> 0
}

function intToIp4(n: number) {
  return [24, 16, 8, 0].map((s) => (n >>> s) & 255).join(".")
}

function ipGroup(title: string, cfg: NM.IPConfig | null, v4: boolean): InfoGroup | null {
  if (!cfg) return null
  const rows: [string, string][] = []
  const addrs = cfg.get_addresses()
  addrs.forEach((a, i) => {
    const label = addrs.length > 1 ? `Address ${i + 1}` : "IP Address"
    rows.push([label, v4 ? a.get_address() : `${a.get_address()}/${a.get_prefix()}`])
    if (v4 && i === 0) {
      const mask = a.get_prefix() === 0 ? 0 : (0xffffffff << (32 - a.get_prefix())) >>> 0
      rows.push(["Broadcast", intToIp4((ip4ToInt(a.get_address()) | ~mask) >>> 0)])
      rows.push(["Subnet Mask", intToIp4(mask)])
    }
  })
  const gw = cfg.get_gateway()
  if (gw) rows.push(["Default Route", gw])
  const dns = cfg.get_nameservers() ?? []
  const names = ["Primary DNS", "Secondary DNS", "Tertiary DNS"]
  dns.forEach((d, i) => rows.push([names[i] ?? `DNS ${i + 1}`, d]))
  const domains = cfg.get_domains?.() ?? []
  if (domains.length) rows.push(["Domains", domains.join(", ")])
  return rows.length ? { title, rows } : null
}

function wifiSecurity(dev: NM.DeviceWifi, conn: NM.Connection | null): string {
  const ap = dev.get_active_access_point()
  if (ap) return SECURITY_LABEL[apSecurity(ap)]
  const km = conn?.get_setting_wireless_security()?.get_key_mgmt()
  return km ? km.toUpperCase() : "None"
}

function interfaceLabel(dev: NM.Device): string {
  const iface = dev.get_iface()
  if (dev instanceof NM.DeviceWifi) return `802.11 Wi-Fi (${iface})`
  if (dev instanceof NM.DeviceEthernet) return `Ethernet (${iface})`
  if (dev instanceof NM.DeviceModem) return `Mobile Broadband (${iface})`
  if (dev instanceof NM.DeviceBt) return `Bluetooth (${iface})`
  return `${deviceName(dev)} (${iface})`
}

export function connectionInfo(ac: NM.ActiveConnection): InfoGroup[] {
  const groups: InfoGroup[] = []
  const conn = ac.get_connection()
  const dev = ac.get_devices()[0] ?? null

  if (ac instanceof NM.VpnConnection || ac.get_connection_type() === "wireguard") {
    const rows: [string, string][] = []
    const sVpn = conn?.get_setting_vpn()
    if (sVpn) {
      rows.push(["VPN Type", sVpn.get_service_type().split(".").pop() ?? sVpn.get_service_type()])
      const gw = sVpn.get_data_item("gateway") ?? sVpn.get_data_item("remote")
      if (gw) rows.push(["VPN Gateway", gw])
      const user = sVpn.get_user_name() ?? sVpn.get_data_item("username")
      if (user) rows.push(["VPN Username", user])
    } else {
      rows.push(["VPN Type", "WireGuard"])
      const wg = conn?.get_setting_by_name("wireguard") as NM.SettingWireGuard | null
      if (wg) rows.push(["Peers", String(wg.get_peers_len())])
    }
    if (ac instanceof NM.VpnConnection && ac.get_banner()) rows.push(["VPN Banner", ac.get_banner()])
    const base = client.get_active_connections().find((a) => a.get_path() === ac.get_specific_object_path())
    rows.push(["Base Connection", base?.get_id() ?? "Unknown"])
    groups.push({ title: "General", rows })
  } else if (dev) {
    const rows: [string, string][] = [["Interface", interfaceLabel(dev)]]
    const hw = dev.get_hw_address()
    if (hw) rows.push(["Hardware Address", hw])
    if (dev.get_driver()) rows.push(["Driver", dev.get_driver()])
    if (dev instanceof NM.DeviceWifi) {
      rows.push(["Speed", formatSpeed(Math.round(dev.get_bitrate() / 1000))])
      rows.push(["Security", wifiSecurity(dev, conn)])
      const ap = dev.get_active_access_point()
      if (ap && !isHotspot(conn)) {
        rows.push(["Signal", `${ap.get_strength()}%`])
        rows.push(["Frequency", `${ap.get_frequency()} MHz`])
        rows.push(["BSSID", ap.get_bssid() ?? ""])
      }
    } else if (dev instanceof NM.DeviceEthernet) {
      rows.push(["Speed", formatSpeed(dev.get_speed())])
      rows.push(["Security", conn?.get_setting_802_1x() ? "802.1X" : "None"])
    }
    if (ac === client.get_primary_connection()) {
      rows.push(["Internet", connectivityText(client.get_connectivity()) ?? "Connected"])
    }
    groups.push({ title: "General", rows })
  }

  const ip4 = ipGroup("IPv4", ac.get_ip4_config(), true)
  if (ip4) groups.push(ip4)
  const ip6 = ipGroup("IPv6", ac.get_ip6_config(), false)
  if (ip6) groups.push(ip6)
  return groups
}

function HotspotSecret({ conn }: { conn: NM.RemoteConnection }) {
  const ssid = ssidText(conn.get_setting_wireless()?.get_ssid() ?? null)
  const [password, setPassword] = createState<string | null>(null)
  const reveal = async () => {
    try {
      const v = await getSecrets(conn, "802-11-wireless-security")
      const s = v.recursiveUnpack() as Record<string, Record<string, string>>
      setPassword(s["802-11-wireless-security"]?.psk ?? "(none)")
    } catch {
      setPassword("(unavailable)")
    }
  }
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={3}>
      <label class="net-info-group" label="Hotspot" halign={Gtk.Align.START} />
      <InfoRow k="Network" v={ssid} />
      <box spacing={12}>
        <label class="bt-info-key" label="Password" widthChars={14} xalign={0} />
        <With value={password}>
          {(p) =>
            p === null ? (
              <button class="bt-chip" onClicked={() => void reveal()}>
                <label label="Show" />
              </button>
            ) : (
              <label class="bt-info-val" label={p} selectable xalign={0} hexpand />
            )
          }
        </With>
      </box>
    </box>
  )
}

function InfoRow({ k, v }: { k: string; v: string }) {
  return (
    <box spacing={12}>
      <label class="bt-info-key" label={k} widthChars={14} xalign={0} />
      <label class="bt-info-val" label={v} selectable xalign={0} hexpand wrap />
    </box>
  )
}

// Live info block; rebuilds when addresses / state change.
export function InfoPanel({ ac }: { ac: NM.ActiveConnection }) {
  const groups = createExternal<InfoGroup[]>(connectionInfo(ac), (set) => {
    const refresh = () => set(connectionInfo(ac))
    const offAc = connectAll(ac, ["notify::ip4-config", "notify::ip6-config", "notify::state"], refresh)
    const dev = ac.get_devices()[0]
    const offDev = dev ? connectAll(dev, ["notify::active-access-point", "notify::ip4-config"], refresh) : () => {}
    return () => (offAc(), offDev())
  })

  const copy = () => {
    const text = groups
      .get()
      .map((g) => [`[${g.title}]`, ...g.rows.map(([k, v]) => `${k}: ${v}`)].join("\n"))
      .join("\n\n")
    execAsync(["wl-copy", text]).catch(() => {})
  }

  const conn = ac.get_connection()
  return (
    <box class="bt-info net-info" orientation={Gtk.Orientation.VERTICAL} spacing={3}>
      <For each={groups}>
        {(g: InfoGroup) => (
          <box orientation={Gtk.Orientation.VERTICAL} spacing={3}>
            <label class="net-info-group" label={g.title} halign={Gtk.Align.START} />
            {g.rows.map(([k, v]) => (
              <InfoRow k={k} v={v} />
            ))}
          </box>
        )}
      </For>
      {conn && isHotspot(conn) && <HotspotSecret conn={conn} />}
      <button class="bt-chip net-copy" halign={Gtk.Align.END} onClicked={copy} tooltipText="Copy all details">
        <label label="Copy" />
      </button>
    </box>
  )
}
