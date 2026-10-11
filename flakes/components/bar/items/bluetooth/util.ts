import Gio from "gi://Gio"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth"
import { createState } from "ags"

// ---- BlueZ object paths ----------------------------------------------------

// /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF -> AA:BB:CC:DD:EE:FF
export function pathToAddress(path: string): string {
  const m = path.match(/dev_([0-9A-Fa-f_]{17})/)
  return m ? m[1].replaceAll("_", ":").toUpperCase() : path
}

export function devicePath(device: AstalBluetooth.Device): string {
  return `${device.adapter}/dev_${device.address.replaceAll(":", "_")}`
}

export function deviceByPath(path: string): AstalBluetooth.Device | null {
  const address = pathToAddress(path)
  return AstalBluetooth.get_default().devices.find((d) => d.address === address) ?? null
}

export function deviceByAddress(address: string): AstalBluetooth.Device | null {
  const a = address.toUpperCase()
  return AstalBluetooth.get_default().devices.find((d) => d.address === a) ?? null
}

export function displayName(device: AstalBluetooth.Device | null, fallback = ""): string {
  return device?.alias || device?.name || device?.address || fallback
}

// ---- async D-Bus ------------------------------------------------------------
// Astal's pair()/connect_profile()/remove_device() are synchronous D-Bus calls.
// Pair() in particular blocks until BlueZ has talked to *our own* agent, which
// can't answer while the main loop is blocked, so everything that may take a
// while goes through these async helpers instead.

export function systemCall(
  path: string,
  iface: string,
  method: string,
  params: GLib.Variant | null = null,
  timeout = -1,
  bus = "org.bluez",
): Promise<GLib.Variant> {
  return new Promise((resolve, reject) => {
    Gio.DBus.system.call(bus, path, iface, method, params, null, Gio.DBusCallFlags.NONE, timeout, null, (conn, res) => {
      try {
        resolve(conn!.call_finish(res))
      } catch (e) {
        reject(e)
      }
    })
  })
}

export function sessionCall(
  bus: string,
  path: string,
  iface: string,
  method: string,
  params: GLib.Variant | null = null,
  timeout = -1,
): Promise<GLib.Variant> {
  return new Promise((resolve, reject) => {
    Gio.DBus.session.call(bus, path, iface, method, params, null, Gio.DBusCallFlags.NONE, timeout, null, (conn, res) => {
      try {
        resolve(conn!.call_finish(res))
      } catch (e) {
        reject(e)
      }
    })
  })
}

const DEVICE_IFACE = "org.bluez.Device1"

export const pairDevice = (d: AstalBluetooth.Device) =>
  systemCall(devicePath(d), DEVICE_IFACE, "Pair", null, 120_000)

export const cancelPairing = (d: AstalBluetooth.Device) =>
  systemCall(devicePath(d), DEVICE_IFACE, "CancelPairing").catch(() => {})

export const connectDevice = (d: AstalBluetooth.Device) =>
  systemCall(devicePath(d), DEVICE_IFACE, "Connect", null, 60_000)

export const disconnectDevice = (d: AstalBluetooth.Device) =>
  systemCall(devicePath(d), DEVICE_IFACE, "Disconnect", null, 30_000)

export const connectProfile = (d: AstalBluetooth.Device, uuid: string) =>
  systemCall(devicePath(d), DEVICE_IFACE, "ConnectProfile", new GLib.Variant("(s)", [uuid]), 60_000)

export const disconnectProfile = (d: AstalBluetooth.Device, uuid: string) =>
  systemCall(devicePath(d), DEVICE_IFACE, "DisconnectProfile", new GLib.Variant("(s)", [uuid]), 30_000)

export const removeDevice = (d: AstalBluetooth.Device) =>
  systemCall(d.adapter, "org.bluez.Adapter1", "RemoveDevice", new GLib.Variant("(o)", [devicePath(d)]))

// Pair (if needed), trust, then connect: the same sequence blueman uses.
export async function pairTrustConnect(d: AstalBluetooth.Device) {
  if (!d.paired) await pairDevice(d)
  if (!d.trusted) d.trusted = true
  if (!d.connected) await connectDevice(d)
}

// ---- errors -----------------------------------------------------------------

// BlueZ >= 5.62 returns machine-readable strings, older ones strerror() text.
// Mapping borrowed from blueman's ManagerDeviceMenu.
const ERROR_MAP: Record<string, string> = {
  "Protocol not available": "No audio endpoints registered (is PipeWire running?)",
  "br-connection-profile-unavailable": "No audio endpoints registered (is PipeWire running?)",
  "Input/output error": "Input/output error",
  "I/O error": "Input/output error",
  "br-connection-create-socket": "Input/output error",
  "le-connection-create-socket": "Input/output error",
  "Host is down": "Device did not respond",
  "br-connection-page-timeout": "Device did not respond",
  "le-connection-abort-by-local": "Connection aborted",
  "br-connection-unknown": "Unknown error",
  "Authentication Failed": "Authentication failed",
  "Authentication Rejected": "Pairing rejected",
  "Authentication Canceled": "Pairing cancelled",
  "Authentication Timeout": "Pairing timed out",
  "Connection Attempt Failed": "Connection attempt failed",
  "Already Exists": "Already paired",
  "Does Not Exist": "Device not found",
  "In Progress": "Already in progress",
  "Not Ready": "Adapter not ready",
  "Timeout was reached": "Timed out",
}

export function isCancelled(e: unknown): boolean {
  const msg = String((e as any)?.message ?? e)
  return /Cancel|br-connection-canceled/i.test(msg)
}

export function errorText(e: unknown): string {
  let msg = String((e as any)?.message ?? e)
  // "GDBus.Error:org.bluez.Error.Failed: br-connection-page-timeout"
  msg = msg.replace(/^GDBus\.Error:[\w.]+:\s*/, "").trim()
  return ERROR_MAP[msg] ?? (msg || "Unknown error")
}

// ---- UUIDs ------------------------------------------------------------------

const BASE = "-0000-1000-8000-00805f9b34fb"
export const uuid16 = (u: string) =>
  u.toLowerCase().endsWith(BASE) ? parseInt(u.slice(0, 8), 16) : -1

const SERVICE_NAMES: Record<number, string> = {
  0x1101: "Serial Port",
  0x1103: "Dial-up Networking",
  0x1105: "Object Push",
  0x1106: "File Transfer",
  0x1108: "Headset",
  0x110a: "Audio Source",
  0x110b: "Audio Sink",
  0x110c: "Remote Control Target",
  0x110d: "Advanced Audio",
  0x110e: "Remote Control",
  0x1112: "Headset Gateway",
  0x1115: "Personal Area Network",
  0x1116: "Network Access Point",
  0x1117: "Group Network",
  0x111e: "Handsfree",
  0x111f: "Handsfree Gateway",
  0x1124: "Input (HID)",
  0x112d: "SIM Access",
  0x112f: "Phonebook Access",
  0x1132: "Message Access",
  0x1200: "PnP Information",
  0x1800: "Generic Access",
  0x1801: "Generic Attribute",
  0x180a: "Device Information",
  0x180d: "Heart Rate",
  0x180f: "Battery",
  0x1812: "Input (HID over GATT)",
  0x184e: "Audio Stream Control",
  0x184f: "Broadcast Audio Scan",
  0x1850: "Published Audio Capabilities",
}

export function serviceName(uuid: string): string {
  const s = uuid16(uuid)
  return SERVICE_NAMES[s] ?? uuid
}

// Profiles worth offering an explicit connect/disconnect for.
const CONNECTABLE = new Set([0x1108, 0x110a, 0x110b, 0x111e, 0x111f, 0x1124, 0x1812, 0x1115, 0x1116, 0x1101])

export function connectableProfiles(device: AstalBluetooth.Device): string[] {
  return (device.uuids ?? []).filter((u) => CONNECTABLE.has(uuid16(u)))
}

export const AUDIO_UUIDS = new Set([0x1108, 0x110a, 0x110b, 0x111e, 0x111f, 0x184e, 0x1850])

export function isAudioDevice(device: AstalBluetooth.Device): boolean {
  if ((device.icon ?? "").startsWith("audio")) return true
  return (device.uuids ?? []).some((u) => AUDIO_UUIDS.has(uuid16(u)))
}

// Class of Device: major 0x05 (peripheral), minor joystick/gamepad.
export function isGameController(device: AstalBluetooth.Device): boolean {
  const cls = device.class & 0x1fff
  return cls === 0x504 || cls === 0x508 || device.icon === "input-gaming"
}

const MAJOR_CLASSES = [
  "Miscellaneous", "Computer", "Phone", "Network", "Audio/Video",
  "Peripheral", "Imaging", "Wearable", "Toy", "Health",
]

export function className(cls: number): string {
  const major = (cls >> 8) & 0x1f
  return MAJOR_CLASSES[major] ?? (major === 0x1f ? "Uncategorized" : "Unknown")
}

export function deviceIcon(device: AstalBluetooth.Device): string {
  const icon = device.icon
  return icon ? `${icon}-symbolic` : "bluetooth-symbolic"
}

export function rssiText(rssi: number): string {
  if (!rssi) return "—"
  const q = rssi >= -55 ? "excellent" : rssi >= -67 ? "good" : rssi >= -80 ? "fair" : "weak"
  return `${rssi} dBm (${q})`
}

export const batteryPct = (b: number) => (b >= 0 ? Math.round(b * 100) : -1)

export function formatBytes(n: number): string {
  const units = ["B", "KB", "MB", "GB"]
  let i = 0
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024
    i++
  }
  return `${n.toFixed(i ? 1 : 0)} ${units[i]}`
}

// ---- desktop notifications --------------------------------------------------
// Sent over the session bus (lands in our own notifd, or any daemon).

export async function notify(
  summary: string,
  body = "",
  icon = "bluetooth-active-symbolic",
  opts: { replaces?: number; transient?: boolean; urgency?: 0 | 1 | 2; timeout?: number } = {},
): Promise<number> {
  const hints: Record<string, GLib.Variant> = {
    urgency: new GLib.Variant("y", opts.urgency ?? 1),
    "desktop-entry": new GLib.Variant("s", "bluetooth"),
  }
  if (opts.transient) hints.transient = new GLib.Variant("b", true)
  try {
    const res = await sessionCall(
      "org.freedesktop.Notifications",
      "/org/freedesktop/Notifications",
      "org.freedesktop.Notifications",
      "Notify",
      new GLib.Variant("(susssasa{sv}i)", [
        "Bluetooth", opts.replaces ?? 0, icon, summary, body, [], hints, opts.timeout ?? -1,
      ]),
    )
    return (res.deepUnpack() as [number])[0]
  } catch (e) {
    console.error("bluetooth: notify failed:", e)
    return 0
  }
}

// ---- persisted settings -----------------------------------------------------

export interface BtSettings {
  notifyConnections: boolean
  notifyLowBattery: boolean
  controllerWakelock: boolean
  acceptFromTrusted: boolean // auto-accept OBEX pushes from trusted devices
  showUnnamed: boolean
  autoConnect: string[] // device addresses
}

const DEFAULTS: BtSettings = {
  notifyConnections: true,
  notifyLowBattery: true,
  controllerWakelock: true,
  acceptFromTrusted: false,
  showUnnamed: false,
  autoConnect: [],
}

const SETTINGS_FILE = GLib.build_filenamev([GLib.get_user_config_dir(), "my-shell", "bluetooth.json"])

function loadSettings(): BtSettings {
  try {
    const [ok, bytes] = GLib.file_get_contents(SETTINGS_FILE)
    if (ok) return { ...DEFAULTS, ...JSON.parse(new TextDecoder().decode(bytes)) }
  } catch {
    // missing / malformed: defaults
  }
  return { ...DEFAULTS }
}

export const [settings, setSettingsState] = createState<BtSettings>(loadSettings())

export function updateSettings(patch: Partial<BtSettings>) {
  const next = { ...settings.get(), ...patch }
  setSettingsState(next)
  try {
    GLib.mkdir_with_parents(GLib.path_get_dirname(SETTINGS_FILE), 0o755)
    GLib.file_set_contents(SETTINGS_FILE, JSON.stringify(next, null, 2))
  } catch (e) {
    console.error("bluetooth: failed to save settings:", e)
  }
}

export function toggleAutoConnect(address: string, on: boolean) {
  const list = settings.get().autoConnect.filter((a) => a !== address)
  updateSettings({ autoConnect: on ? [...list, address] : list })
}
