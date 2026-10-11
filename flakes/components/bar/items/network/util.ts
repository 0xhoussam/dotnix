import { createState } from "ags"
import { execAsync } from "ags/process"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import GObject from "gi://GObject"
import NM from "gi://NM"
import AstalNetwork from "gi://AstalNetwork"

// Shared NetworkManager helpers for the network module (nm-applet parity):
// libnm promise wrappers, Wi-Fi security classification, state/reason text,
// notifications and persisted settings.

export const client: NM.Client = AstalNetwork.get_default().client

// ---- libnm async ------------------------------------------------------------

export function nmAsync<T>(
  start: (cb: (src: any, res: Gio.AsyncResult) => void) => void,
  finish: (res: Gio.AsyncResult) => T,
): Promise<T> {
  return new Promise((resolve, reject) => {
    start((_src, res) => {
      try {
        resolve(finish(res))
      } catch (e) {
        reject(e)
      }
    })
  })
}

export const activateConnection = (conn: NM.Connection | null, dev: NM.Device | null, specific: string | null = null) =>
  nmAsync<NM.ActiveConnection>(
    (cb) => client.activate_connection_async(conn, dev, specific, null, cb),
    (r) => client.activate_connection_finish(r),
  )

export const addAndActivate = (partial: NM.Connection | null, dev: NM.Device | null, specific: string | null = null) =>
  nmAsync<NM.ActiveConnection>(
    (cb) => client.add_and_activate_connection_async(partial, dev, specific, null, cb),
    (r) => client.add_and_activate_connection_finish(r),
  )

export const addConnection = (conn: NM.Connection) =>
  nmAsync<NM.RemoteConnection>(
    (cb) => client.add_connection_async(conn, true, null, cb),
    (r) => client.add_connection_finish(r),
  )

export const deactivate = (ac: NM.ActiveConnection) =>
  nmAsync<boolean>(
    (cb) => client.deactivate_connection_async(ac, null, cb),
    (r) => client.deactivate_connection_finish(r),
  )

export const disconnectDevice = (dev: NM.Device) =>
  nmAsync<boolean>(
    (cb) => dev.disconnect_async(null, cb),
    (r) => dev.disconnect_finish(r),
  )

export const deleteConnection = (conn: NM.RemoteConnection) =>
  nmAsync<boolean>(
    (cb) => conn.delete_async(null, cb),
    (r) => conn.delete_finish(r),
  )

export const commitConnection = (conn: NM.RemoteConnection) =>
  nmAsync<boolean>(
    (cb) => conn.commit_changes_async(true, null, cb),
    (r) => conn.commit_changes_finish(r),
  )

export const getSecrets = (conn: NM.RemoteConnection, setting: string) =>
  nmAsync<GLib.Variant>(
    (cb) => conn.get_secrets_async(setting, null, cb),
    (r) => conn.get_secrets_finish(r),
  )

export const requestScan = (dev: NM.DeviceWifi) =>
  nmAsync<boolean>(
    (cb) => dev.request_scan_async(null, cb),
    (r) => dev.request_scan_finish(r),
  ).catch(() => false) // rate limited / busy

// Set a property on the NetworkManager root object (WirelessEnabled, ...).
export const setNmProperty = (name: string, value: GLib.Variant) =>
  nmAsync<boolean>(
    (cb) => client.dbus_set_property(
      "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", name, value, -1, null, cb),
    (r) => client.dbus_set_property_finish(r),
  )

export const setWifiEnabled = (on: boolean) => setNmProperty("WirelessEnabled", new GLib.Variant("b", on))
export const setWwanEnabled = (on: boolean) => setNmProperty("WwanEnabled", new GLib.Variant("b", on))

export const setNetworkingEnabled = (on: boolean) =>
  nmAsync<GLib.Variant>(
    (cb) => client.dbus_call(
      "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "Enable",
      new GLib.Variant("(b)", [on]), null, -1, null, cb),
    (r) => client.dbus_call_finish(r),
  ).catch((e) => {
    if (!String(e).includes("AlreadyEnabledOrDisabled")) throw e
  })

export const canModifySystem = () =>
  client.get_permission_result(NM.ClientPermission.SETTINGS_MODIFY_SYSTEM) === NM.ClientPermissionResult.YES

export function openEditor(args: string[] = []) {
  execAsync(["nm-connection-editor", ...args]).catch((e) => console.error("network: nm-connection-editor:", e))
}

export function openUri(uri: string) {
  try {
    Gio.AppInfo.launch_default_for_uri(uri, null)
  } catch (e) {
    console.error("network: open uri failed:", e)
  }
}

// ---- Wi-Fi ------------------------------------------------------------------

export function ssidText(bytes: GLib.Bytes | null): string {
  if (!bytes) return ""
  const data = bytes.get_data()
  if (!data || data.length === 0) return ""
  return NM.utils_ssid_to_utf8(data) ?? ""
}

export function ssidBytes(ssid: string): GLib.Bytes {
  return new GLib.Bytes(new TextEncoder().encode(ssid))
}

const isEmptySsid = (b: GLib.Bytes | null) => {
  const d = b?.get_data()
  return !d || d.length === 0 || d.every((c) => c === 0)
}

// Hidden-SSID beacons and the NPR "Free Public WiFi" ad-hoc virus.
const DENYLISTED = new Set(["Free Public WiFi"])

export function isListable(ap: NM.AccessPoint): boolean {
  const ssid = ap.get_ssid()
  return !isEmptySsid(ssid) && !DENYLISTED.has(ssidText(ssid))
}

// Router-default SSIDs: new connections get locked to the BSSID so we don't
// wander onto some other "linksys".
const MANUFACTURER_DEFAULT = new Set([
  "linksys", "linksys-a", "linksys-g", "default", "belkin54g", "NETGEAR", "o2DSL", "WLAN", "ALICE-WLAN",
])
export const isManufacturerDefault = (ssid: string) => MANUFACTURER_DEFAULT.has(ssid)

export type Security = "none" | "owe" | "wep" | "wpa" | "wpa2" | "wpa3" | "wpa2-wpa3" | "enterprise" | "enterprise-192"

const KM_PSK = 0x100
const KM_8021X = 0x200
const KM_SAE = 0x400
const KM_OWE = 0x800
const KM_OWE_TM = 0x1000
const KM_EAP_SUITE_B_192 = 0x2000
const AP_FLAG_PRIVACY = 0x1

export function apSecurity(ap: NM.AccessPoint): Security {
  const wpa = ap.get_wpa_flags()
  const rsn = ap.get_rsn_flags()
  const all = wpa | rsn
  if (all & KM_EAP_SUITE_B_192) return "enterprise-192"
  if (all & KM_8021X) return "enterprise"
  if (all & KM_SAE) return all & KM_PSK ? "wpa2-wpa3" : "wpa3"
  if (rsn & KM_PSK) return "wpa2"
  if (wpa & KM_PSK) return "wpa"
  if (all & (KM_OWE | KM_OWE_TM)) return "owe"
  if (ap.get_flags() & AP_FLAG_PRIVACY) return "wep"
  return "none"
}

export const SECURITY_LABEL: Record<Security, string> = {
  none: "Open",
  owe: "Enhanced Open",
  wep: "WEP",
  wpa: "WPA",
  wpa2: "WPA2",
  wpa3: "WPA3",
  "wpa2-wpa3": "WPA2/WPA3",
  enterprise: "Enterprise",
  "enterprise-192": "WPA3 Enterprise",
}

export const isSecured = (s: Security) => s !== "none" && s !== "owe"

// Needs our own join form instead of NM's auto-completion + agent prompt.
export const needsForm = (s: Security) => s === "wep" || s === "enterprise" || s === "enterprise-192"

export function band(freq: number): string {
  if (freq >= 5925) return "6 GHz"
  if (freq >= 4900) return "5 GHz"
  if (freq >= 2400) return "2.4 GHz"
  return freq ? `${freq} MHz` : "—"
}

export function channel(freq: number): number {
  if (freq === 2484) return 14
  if (freq >= 2412 && freq < 2484) return (freq - 2407) / 5
  if (freq >= 5955) return (freq - 5950) / 5
  if (freq >= 5000) return (freq - 5000) / 5
  return 0
}

export function strengthIcon(s: number, prefix = "network-wireless-signal"): string {
  const level = s > 80 ? "excellent" : s > 55 ? "good" : s > 30 ? "ok" : s > 5 ? "weak" : "none"
  return `${prefix}-${level}-symbolic`
}

export const AP_MODE_ADHOC = 1
export const AP_MODE_INFRA = 2
export const AP_MODE_AP = 3

// The connection's mode, e.g. "ap" for a hotspot we're running.
export function wifiMode(conn: NM.Connection | null): string {
  return conn?.get_setting_wireless()?.get_mode() ?? ""
}

// Saved connections usable on a device / matching an AP. (libnm's
// filter_connections() hands GJS unowned references and crashes it.)
export function deviceConnections(dev: NM.Device): NM.RemoteConnection[] {
  return client.get_connections().filter((c) => {
    try {
      return dev.connection_valid(c)
    } catch {
      return false
    }
  })
}

export const apMatches = (ap: NM.AccessPoint, c: NM.Connection) => {
  try {
    return ap.connection_valid(c)
  } catch {
    return false
  }
}

export const isHotspot = (conn: NM.Connection | null) => {
  const m = wifiMode(conn)
  return m === "ap" || m === "adhoc"
}

// ---- states / reasons ---------------------------------------------------------

const DSR = NM.DeviceStateReason
const DEVICE_REASON: Partial<Record<number, string>> = {
  [DSR.CONFIG_FAILED]: "Configuration failed",
  [DSR.IP_CONFIG_UNAVAILABLE]: "Couldn't get an IP address",
  [DSR.IP_CONFIG_EXPIRED]: "IP address lease expired",
  [DSR.NO_SECRETS]: "Password required",
  [DSR.SUPPLICANT_DISCONNECT]: "Authentication failed — wrong password?",
  [DSR.SUPPLICANT_CONFIG_FAILED]: "Wi-Fi configuration rejected",
  [DSR.SUPPLICANT_FAILED]: "Wi-Fi supplicant failed",
  [DSR.SUPPLICANT_TIMEOUT]: "Authentication timed out — wrong password?",
  [DSR.PPP_START_FAILED]: "PPP failed to start",
  [DSR.PPP_DISCONNECT]: "PPP disconnected",
  [DSR.PPP_FAILED]: "PPP failed",
  [DSR.DHCP_START_FAILED]: "DHCP failed to start",
  [DSR.DHCP_ERROR]: "DHCP error",
  [DSR.DHCP_FAILED]: "Couldn't get an IP address (DHCP)",
  [DSR.SHARED_START_FAILED]: "Connection sharing failed to start",
  [DSR.SHARED_FAILED]: "Connection sharing failed",
  [DSR.AUTOIP_START_FAILED]: "Link-local addressing failed to start",
  [DSR.AUTOIP_FAILED]: "Link-local addressing failed",
  [DSR.MODEM_BUSY]: "Modem busy",
  [DSR.MODEM_NO_DIAL_TONE]: "Modem has no dial tone",
  [DSR.MODEM_NO_CARRIER]: "Modem has no carrier",
  [DSR.MODEM_DIAL_TIMEOUT]: "Modem dial timed out",
  [DSR.MODEM_DIAL_FAILED]: "Modem dial failed",
  [DSR.MODEM_INIT_FAILED]: "Modem initialization failed",
  [DSR.GSM_APN_FAILED]: "APN selection failed",
  [DSR.GSM_REGISTRATION_DENIED]: "Mobile network registration denied",
  [DSR.GSM_REGISTRATION_TIMEOUT]: "Mobile network registration timed out",
  [DSR.GSM_REGISTRATION_FAILED]: "Mobile network registration failed",
  [DSR.GSM_PIN_CHECK_FAILED]: "SIM PIN check failed",
  [DSR.GSM_SIM_NOT_INSERTED]: "No SIM card",
  [DSR.GSM_SIM_PIN_REQUIRED]: "SIM PIN required",
  [DSR.GSM_SIM_PUK_REQUIRED]: "SIM PUK required",
  [DSR.GSM_SIM_WRONG]: "Wrong SIM card",
  [DSR.SIM_PIN_INCORRECT]: "Incorrect SIM PIN",
  [DSR.FIRMWARE_MISSING]: "Firmware missing",
  [DSR.REMOVED]: "Device removed",
  [DSR.SLEEPING]: "System is sleeping",
  [DSR.CONNECTION_REMOVED]: "Connection was removed",
  [DSR.USER_REQUESTED]: "Disconnected by user",
  [DSR.CARRIER]: "Cable unplugged",
  [DSR.MODEM_NOT_FOUND]: "Modem not found",
  [DSR.BT_FAILED]: "Bluetooth connection failed",
  [DSR.DEPENDENCY_FAILED]: "A required connection failed",
  [DSR.MODEM_MANAGER_UNAVAILABLE]: "ModemManager is not running",
  [DSR.SSID_NOT_FOUND]: "Network not found",
  [DSR.SECONDARY_CONNECTION_FAILED]: "Secondary connection (VPN) failed",
  [DSR.MODEM_FAILED]: "Modem failed",
  [DSR.IP_ADDRESS_DUPLICATE]: "IP address already in use",
  [DSR.IP_METHOD_UNSUPPORTED]: "IP method not supported",
  [DSR.PEER_NOT_FOUND]: "Peer not found",
  [DSR.NETWORKING_OFF]: "Networking is disabled",
}

export const deviceReasonText = (r: number) => DEVICE_REASON[r] ?? "Connection failed"

const ACR = NM.ActiveConnectionStateReason
const ACTIVE_REASON: Partial<Record<number, string>> = {
  [ACR.USER_DISCONNECTED]: "Disconnected by user",
  [ACR.DEVICE_DISCONNECTED]: "The network connection was interrupted",
  [ACR.SERVICE_STOPPED]: "The VPN service stopped unexpectedly",
  [ACR.IP_CONFIG_INVALID]: "The service returned an invalid configuration",
  [ACR.CONNECT_TIMEOUT]: "The connection attempt timed out",
  [ACR.SERVICE_START_TIMEOUT]: "The service did not start in time",
  [ACR.SERVICE_START_FAILED]: "The service failed to start",
  [ACR.NO_SECRETS]: "No valid secrets",
  [ACR.LOGIN_FAILED]: "Invalid secrets (login failed)",
  [ACR.CONNECTION_REMOVED]: "The connection was removed",
  [ACR.DEPENDENCY_FAILED]: "A required connection failed",
  [ACR.DEVICE_REMOVED]: "The device was removed",
}

export const activeReasonText = (r: number) => ACTIVE_REASON[r] ?? "Connection failed"

// Row status while a device works through activation.
export function deviceStateText(state: number): string | null {
  const S = NM.DeviceState
  switch (state) {
    case S.PREPARE:
    case S.CONFIG:
      return "Connecting…"
    case S.NEED_AUTH:
      return "Authenticating…"
    case S.IP_CONFIG:
    case S.IP_CHECK:
    case S.SECONDARIES:
      return "Getting IP address…"
    case S.DEACTIVATING:
      return "Disconnecting…"
    default:
      return null
  }
}

export const isActivating = (state: number) => state >= NM.DeviceState.PREPARE && state < NM.DeviceState.ACTIVATED

// Why a device can't be used right now (nm-applet's nma_menu_device_get_menu_item).
export function unusableText(dev: NM.Device): string | null {
  const S = NM.DeviceState
  switch (dev.get_state()) {
    case S.UNMANAGED:
      return "Device not managed"
    case S.UNAVAILABLE:
      if (dev.get_firmware_missing()) return "Device not ready (firmware missing)"
      if (dev instanceof NM.DeviceEthernet) return "Cable unplugged"
      if (dev instanceof NM.DeviceWifi) {
        if (!client.wireless_hardware_get_enabled()) return "Wi-Fi is disabled by hardware switch"
        if (!client.wireless_get_enabled()) return "Wi-Fi is disabled"
      }
      return "Device not ready"
    default:
      return null
  }
}

export function connectivityText(c: number): string | null {
  const C = NM.ConnectivityState
  if (c === C.PORTAL) return "Sign-in required"
  if (c === C.LIMITED) return "Limited connectivity"
  if (c === C.NONE) return "No internet"
  return null
}

export function errorText(e: unknown): string {
  let msg = String((e as any)?.message ?? e)
  msg = msg.replace(/^GDBus\.Error:[\w.]+:\s*/, "").trim()
  if (/not authorized|NotAuthorized|PermissionDenied/i.test(msg)) return "Not authorized"
  if (/Cancel/i.test(msg)) return "Cancelled"
  return msg || "Unknown error"
}

// ---- connection helpers -----------------------------------------------------

export const connType = (c: NM.Connection) => c.get_connection_type() ?? ""

export const isVpnLike = (c: NM.Connection) => {
  const t = connType(c)
  return t === "vpn" || t === "wireguard"
}

export function activeFor(conn: NM.Connection): NM.ActiveConnection | null {
  const uuid = conn.get_uuid()
  return client.get_active_connections().find((ac) => ac.get_uuid() === uuid) ?? null
}

export function deviceTypeIcon(dev: NM.Device | null): string {
  if (dev instanceof NM.DeviceWifi) return "network-wireless-symbolic"
  if (dev instanceof NM.DeviceModem) return "network-cellular-symbolic"
  if (dev instanceof NM.DeviceBt) return "bluetooth-active-symbolic"
  return "network-wired-symbolic"
}

export function deviceName(dev: NM.Device): string {
  return dev.get_description() || dev.get_product() || dev.get_iface() || "Network device"
}

export function formatSpeed(mbit: number): string {
  if (!mbit) return "Unknown"
  return mbit >= 1000 ? `${(mbit / 1000).toFixed(mbit % 1000 ? 1 : 0)} Gb/s` : `${mbit} Mb/s`
}

// Debounced callback (GLib timeout), returns [trigger, dispose].
export function debounce(ms: number, fn: () => void): [() => void, () => void] {
  let id = 0
  const trigger = () => {
    if (id) return
    id = GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
      id = 0
      fn()
      return GLib.SOURCE_REMOVE
    })
  }
  const dispose = () => {
    if (id) GLib.source_remove(id)
    id = 0
  }
  return [trigger, dispose]
}

// NM.Device has its own disconnect() (deactivate the device), which shadows
// GObject's disconnect(handlerId) — always drop handlers through this.
export const unbind = (obj: GObject.Object, id: number) => GObject.signal_handler_disconnect(obj, id)

// Connect several signals on a GObject; returns a disposer.
export function connectAll(obj: any, signals: string[], fn: (...args: any[]) => void): () => void {
  const ids = signals.map((s) => obj.connect(s, fn))
  return () => ids.forEach((id) => unbind(obj, id))
}

// ---- notifications ------------------------------------------------------------

function sessionCall(method: string, params: GLib.Variant): Promise<GLib.Variant> {
  return new Promise((resolve, reject) => {
    Gio.DBus.session.call(
      "org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications",
      method, params, null, Gio.DBusCallFlags.NONE, -1, null,
      (conn, res) => {
        try {
          resolve(conn!.call_finish(res))
        } catch (e) {
          reject(e)
        }
      })
  })
}

const actionHandlers = new Map<number, (action: string) => void>()
let actionSub = 0

function watchActions() {
  if (actionSub) return
  const bus = Gio.DBus.session
  actionSub = bus.signal_subscribe(
    null, "org.freedesktop.Notifications", "ActionInvoked", "/org/freedesktop/Notifications", null,
    Gio.DBusSignalFlags.NONE,
    (_c, _s, _p, _i, _sig, params) => {
      const [id, action] = params.deepUnpack() as [number, string]
      actionHandlers.get(id)?.(action)
    })
  bus.signal_subscribe(
    null, "org.freedesktop.Notifications", "NotificationClosed", "/org/freedesktop/Notifications", null,
    Gio.DBusSignalFlags.NONE,
    (_c, _s, _p, _i, _sig, params) => {
      const [id] = params.deepUnpack() as [number, number]
      actionHandlers.delete(id)
    })
}

export async function notify(
  summary: string,
  body = "",
  icon = "network-wireless-symbolic",
  opts: {
    replaces?: number
    transient?: boolean
    urgency?: 0 | 1 | 2
    timeout?: number
    actions?: [string, string][] // [id, label]
    onAction?: (id: string) => void
  } = {},
): Promise<number> {
  const hints: Record<string, GLib.Variant> = {
    urgency: new GLib.Variant("y", opts.urgency ?? 1),
    "desktop-entry": new GLib.Variant("s", "nm-applet"),
  }
  if (opts.transient) hints.transient = new GLib.Variant("b", true)
  const actions = (opts.actions ?? []).flat()
  try {
    const res = await sessionCall(
      "Notify",
      new GLib.Variant("(susssasa{sv}i)", [
        "Network", opts.replaces ?? 0, icon, summary, body, actions, hints, opts.timeout ?? -1,
      ]),
    )
    const id = (res.deepUnpack() as [number])[0]
    if (opts.onAction) {
      watchActions()
      actionHandlers.set(id, opts.onAction)
    }
    return id
  } catch (e) {
    console.error("network: notify failed:", e)
    return 0
  }
}

// ---- persisted settings -----------------------------------------------------

export interface NetSettings {
  notifyConnected: boolean
  notifyDisconnected: boolean
  notifyVpn: boolean
  notifyAvailable: boolean // "Wi-Fi networks available"
}

const DEFAULTS: NetSettings = {
  notifyConnected: true,
  notifyDisconnected: true,
  notifyVpn: true,
  notifyAvailable: true,
}

const SETTINGS_FILE = GLib.build_filenamev([GLib.get_user_config_dir(), "my-shell", "network.json"])

function loadSettings(): NetSettings {
  try {
    const [ok, bytes] = GLib.file_get_contents(SETTINGS_FILE)
    if (ok) return { ...DEFAULTS, ...JSON.parse(new TextDecoder().decode(bytes)) }
  } catch {
    // missing / malformed: defaults
  }
  return { ...DEFAULTS }
}

export const [settings, setSettingsState] = createState<NetSettings>(loadSettings())

export function updateSettings(patch: Partial<NetSettings>) {
  const next = { ...settings.get(), ...patch }
  setSettingsState(next)
  try {
    GLib.mkdir_with_parents(GLib.path_get_dirname(SETTINGS_FILE), 0o755)
    GLib.file_set_contents(SETTINGS_FILE, JSON.stringify(next, null, 2))
  } catch (e) {
    console.error("network: failed to save settings:", e)
  }
}
