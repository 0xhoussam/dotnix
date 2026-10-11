import { createState } from "ags"
import GLib from "gi://GLib"
import NM from "gi://NM"
import {
  activeReasonText, addAndActivate, addConnection, activateConnection, canModifySystem, client, commitConnection,
  deleteConnection, deviceReasonText, isHotspot, ssidBytes, unbind,
} from "./util"

// Building NetworkManager connections (nm-applet's wifi dialog / libnma
// wireless-security widgets) and activating them with progress tracking.

// ---- activation ------------------------------------------------------------------

// Resolve once the active connection is up; reject with a readable reason.
export function waitActivated(ac: NM.ActiveConnection, dev: NM.Device | null): Promise<void> {
  return new Promise((resolve, reject) => {
    let devReason = 0
    let finished = false
    const ids: [any, number][] = []
    const finish = (err?: Error) => {
      if (finished) return
      finished = true
      ids.forEach(([o, id]) => unbind(o, id))
      err ? reject(err) : resolve()
    }
    const check = () => {
      const st = ac.get_state()
      if (st === NM.ActiveConnectionState.ACTIVATED) finish()
      else if (st === NM.ActiveConnectionState.DEACTIVATED)
        finish(new Error(devReason ? deviceReasonText(devReason) : activeReasonText(ac.get_state_reason())))
    }
    ids.push([ac, ac.connect("state-changed", check)])
    const d = dev ?? ac.get_devices()[0] ?? null
    if (d)
      ids.push([d, d.connect("state-changed", (_d: NM.Device, ns: number, _os: number, reason: number) => {
        if (ns === NM.DeviceState.FAILED) devReason = reason
      })])
    check()
  })
}

// Activate (or add + activate) and wait for the result. A connection created
// here that never came up is removed again, so cancelling the password
// prompt doesn't leave a broken saved network behind.
export async function connectAndWait(opts: {
  conn?: NM.Connection | null
  partial?: NM.Connection | null
  device: NM.Device | null
  specific?: string | null
  removeOnFailure?: boolean
}): Promise<void> {
  const { device, specific = null } = opts
  const ac = opts.conn
    ? await activateConnection(opts.conn, device, specific)
    : await addAndActivate(opts.partial ?? null, device, specific)
  try {
    await waitActivated(ac, device)
  } catch (e) {
    const remote = ac.get_connection()
    if (!opts.conn && opts.removeOnFailure !== false && remote) await deleteConnection(remote).catch(() => {})
    throw e
  }
}

// ---- Wi-Fi connection form ---------------------------------------------------------

export type SecKind =
  | "none" | "owe" | "wep-key" | "wep-pass" | "leap" | "dynamic-wep" | "wpa-psk" | "sae" | "wpa-eap" | "wpa3-eap"

export const SEC_OPTIONS: [SecKind, string][] = [
  ["none", "None"],
  ["owe", "Enhanced Open (OWE)"],
  ["wep-key", "WEP 40/128-bit Key (Hex or ASCII)"],
  ["wep-pass", "WEP 128-bit Passphrase"],
  ["leap", "LEAP"],
  ["dynamic-wep", "Dynamic WEP (802.1X)"],
  ["wpa-psk", "WPA & WPA2 Personal"],
  ["sae", "WPA3 Personal"],
  ["wpa-eap", "WPA & WPA2 Enterprise"],
  ["wpa3-eap", "WPA3 Enterprise"],
]

export const isEap = (s: SecKind) => s === "dynamic-wep" || s === "wpa-eap" || s === "wpa3-eap"

export type EapMethod = "tls" | "peap" | "ttls" | "pwd" | "fast" | "leap" | "md5"

export const EAP_OPTIONS: [EapMethod, string][] = [
  ["tls", "TLS"],
  ["peap", "Protected EAP (PEAP)"],
  ["ttls", "Tunneled TLS"],
  ["pwd", "PWD"],
  ["fast", "FAST"],
  ["leap", "LEAP"],
  ["md5", "MD5"],
]

// WPA3 Enterprise (Suite-B 192) is TLS only; LEAP/MD5 only make sense for Dynamic WEP.
export function eapOptionsFor(sec: SecKind): [EapMethod, string][] {
  if (sec === "wpa3-eap") return EAP_OPTIONS.filter(([m]) => m === "tls")
  if (sec === "wpa-eap") return EAP_OPTIONS.filter(([m]) => m !== "md5")
  return EAP_OPTIONS
}

// Inner (phase 2) auth per tunnel method: [label, property, value].
export const INNER: Record<string, [string, "phase2_auth" | "phase2_autheap", string][]> = {
  peap: [["MSCHAPv2", "phase2_auth", "mschapv2"], ["MD5", "phase2_auth", "md5"], ["GTC", "phase2_auth", "gtc"]],
  ttls: [
    ["PAP", "phase2_auth", "pap"],
    ["MSCHAP", "phase2_auth", "mschap"],
    ["MSCHAPv2 (no EAP)", "phase2_auth", "mschapv2"],
    ["CHAP", "phase2_auth", "chap"],
    ["MD5", "phase2_autheap", "md5"],
    ["MSCHAPv2", "phase2_autheap", "mschapv2"],
    ["GTC", "phase2_autheap", "gtc"],
  ],
  fast: [["GTC", "phase2_auth", "gtc"], ["MSCHAPv2", "phase2_auth", "mschapv2"]],
}

export const PEAP_VERSIONS: [string, string][] = [["", "Automatic"], ["0", "Version 0"], ["1", "Version 1"]]
export const FAST_PROVISIONING: [string, string][] = [
  ["0", "Disabled"], ["1", "Anonymous"], ["2", "Authenticated"], ["3", "Both"],
]

// Where passwords go: NM's system store, the user's keyring, or nowhere.
export type Storage = "system" | "user" | "ask"
export const STORAGE_OPTIONS: [Storage, string][] = [
  ["user", "Store for this user only"],
  ["system", "Store for all users"],
  ["ask", "Ask for this password every time"],
]
const storageFlags = (s: Storage) =>
  s === "user" ? NM.SettingSecretFlags.AGENT_OWNED : s === "ask" ? NM.SettingSecretFlags.NOT_SAVED : NM.SettingSecretFlags.NONE

export interface WifiForm {
  ssid: string
  hidden: boolean
  bssid: string
  security: SecKind
  storage: Storage
  password: string // PSK / SAE / LEAP / EAP password
  wepKey: string
  wepIndex: number // 0..3
  wepAuth: "open" | "shared"
  username: string // LEAP / EAP identity
  eap: EapMethod
  anonIdentity: string
  domain: string
  caCert: string
  noCa: boolean
  clientCert: string
  privateKey: string
  keyPassword: string
  inner: number // index into INNER[eap]
  peapVersion: string
  fastProvisioning: string
  pacFile: string
}

export const emptyWifiForm = (): WifiForm => ({
  ssid: "", hidden: false, bssid: "", security: "wpa-psk", storage: "user", password: "", wepKey: "", wepIndex: 0,
  wepAuth: "open", username: "", eap: "peap", anonIdentity: "", domain: "", caCert: "", noCa: false, clientCert: "",
  privateKey: "", keyPassword: "", inner: 0, peapVersion: "", fastProvisioning: "1", pacFile: "",
})

// Returns an error message, or null if the form can be submitted.
export function validateWifiForm(f: WifiForm): string | null {
  if (!f.ssid) return "Enter the network name (SSID)"
  if (new TextEncoder().encode(f.ssid).length > 32) return "Network name is longer than 32 bytes"
  const ask = f.storage === "ask"
  switch (f.security) {
    case "wpa-psk":
      if (ask) return null
      if (f.password.length === 64 && /^[0-9a-f]+$/i.test(f.password)) return null
      return f.password.length >= 8 && f.password.length <= 63 ? null : "Password must be 8–63 characters"
    case "sae":
      return ask || f.password ? null : "Enter a password"
    case "wep-key": {
      const k = f.wepKey
      const ok = ((k.length === 10 || k.length === 26) && /^[0-9a-f]+$/i.test(k)) || k.length === 5 || k.length === 13
      return ask || ok ? null : "WEP keys are 5/13 characters or 10/26 hex digits"
    }
    case "wep-pass":
      return ask || (f.wepKey && f.wepKey.length <= 64) ? null : "Enter a passphrase (up to 64 characters)"
    case "leap":
      return f.username ? null : "Enter a username"
  }
  if (isEap(f.security)) {
    if (f.eap === "tls") {
      if (!f.username) return "Enter an identity"
      if (!f.clientCert) return "Choose a user certificate"
      if (!f.privateKey) return "Choose a private key"
    } else if (!f.username && f.eap !== "fast") return "Enter a username"
    if ((f.eap === "tls" || f.eap === "peap" || f.eap === "ttls") && !f.noCa && !f.caCert)
      return "Choose a CA certificate or tick “No CA certificate is required”"
    if (f.eap === "fast" && f.fastProvisioning === "0" && !f.pacFile) return "Choose a PAC file or enable provisioning"
  }
  return null
}

function baseConnection(id: string, type: string): [NM.SimpleConnection, NM.SettingConnection] {
  const c = NM.SimpleConnection.new()
  const sCon = new NM.SettingConnection({ id, uuid: NM.utils_uuid_generate(), type, autoconnect: true })
  // Without system-wide permission the connection is private to this user.
  if (!canModifySystem()) sCon.add_permission("user", GLib.get_user_name(), null)
  c.add_setting(sCon)
  return [c, sCon]
}

const PATH = NM.Setting8021xCKScheme.PATH

function eapSetting(f: WifiForm): NM.Setting8021x {
  const s = new NM.Setting8021x()
  s.add_eap_method(f.eap)
  const flags = storageFlags(f.storage)
  if (f.username) s.identity = f.username
  if (f.anonIdentity && f.eap !== "tls") s.anonymous_identity = f.anonIdentity
  if (f.domain) s.domain_suffix_match = f.domain
  if (!f.noCa && f.caCert && f.eap !== "pwd" && f.eap !== "leap" && f.eap !== "md5") s.set_ca_cert(f.caCert, PATH, null)

  if (f.eap === "tls") {
    // (the trailing null is libnm's unannotated out_format pointer)
    if (f.clientCert) s.set_client_cert(f.clientCert, PATH, null)
    if (f.privateKey) s.set_private_key(f.privateKey, f.storage === "ask" ? null : f.keyPassword || null, PATH, null)
    s.private_key_password_flags = flags
  } else {
    s.password_flags = flags
    if (f.storage !== "ask" && f.password) s.password = f.password
  }

  const inner = INNER[f.eap]?.[f.inner] ?? INNER[f.eap]?.[0]
  if (inner) (s as any)[inner[1]] = inner[2]
  if (f.eap === "peap" && f.peapVersion) s.phase1_peapver = f.peapVersion
  if (f.eap === "fast") {
    s.phase1_fast_provisioning = f.fastProvisioning
    if (f.pacFile) s.pac_file = f.pacFile
  }
  return s
}

export function buildWifiConnection(f: WifiForm): NM.Connection {
  const [c] = baseConnection(f.ssid, "802-11-wireless")
  const sWifi = new NM.SettingWireless({ ssid: ssidBytes(f.ssid), mode: "infrastructure", hidden: f.hidden })
  if (f.bssid) sWifi.bssid = f.bssid
  c.add_setting(sWifi)
  c.add_setting(new NM.SettingIP4Config({ method: "auto" }))
  c.add_setting(new NM.SettingIP6Config({ method: "auto" }))

  const flags = storageFlags(f.storage)
  const keep = f.storage !== "ask"
  const wsec = (props: Record<string, unknown>) => {
    const s = new NM.SettingWirelessSecurity(props as any)
    c.add_setting(s)
    return s
  }

  switch (f.security) {
    case "none":
      break
    case "owe":
      wsec({ key_mgmt: "owe" })
      break
    case "wep-key":
    case "wep-pass": {
      const s = wsec({
        key_mgmt: "none",
        wep_key_type: f.security === "wep-key" ? NM.WepKeyType.KEY : NM.WepKeyType.PASSPHRASE,
        wep_tx_keyidx: f.wepIndex,
        auth_alg: f.wepAuth,
        wep_key_flags: flags,
      })
      if (keep) s.set_wep_key(f.wepIndex, f.wepKey)
      break
    }
    case "leap":
      wsec({
        key_mgmt: "ieee8021x", auth_alg: "leap", leap_username: f.username, leap_password_flags: flags,
        ...(keep && f.password ? { leap_password: f.password } : {}),
      })
      break
    case "wpa-psk":
    case "sae":
      wsec({ key_mgmt: f.security, psk_flags: flags, ...(keep && f.password ? { psk: f.password } : {}) })
      break
    case "dynamic-wep":
      wsec({ key_mgmt: "ieee8021x" })
      c.add_setting(eapSetting(f))
      break
    case "wpa-eap":
      wsec({ key_mgmt: "wpa-eap" })
      c.add_setting(eapSetting(f))
      break
    case "wpa3-eap":
      wsec({ key_mgmt: "wpa-eap-suite-b-192" })
      c.add_setting(eapSetting({ ...f, eap: "tls" }))
      break
  }
  return c
}

// ---- hotspot ------------------------------------------------------------------------

export interface HotspotForm {
  ssid: string
  security: "wpa-psk" | "sae" | "none"
  password: string
  band: "" | "bg" | "a"
}

export const HOTSPOT_ID = "Hotspot"

export function defaultHotspot(): HotspotForm {
  const chars = "abcdefghijkmnpqrstuvwxyz23456789"
  let password = ""
  for (let i = 0; i < 10; i++) password += chars[Math.floor(Math.random() * chars.length)]
  return { ssid: GLib.get_host_name() || "Hotspot", security: "wpa-psk", password, band: "" }
}

export const hotspotCapable = (dev: NM.DeviceWifi) =>
  (dev.get_capabilities() & NM.DeviceWifiCapabilities.AP) !== 0

export function validateHotspot(f: HotspotForm): string | null {
  if (!f.ssid) return "Enter a network name"
  if (f.security !== "none" && (f.password.length < 8 || f.password.length > 63)) return "Password must be 8–63 characters"
  return null
}

export function buildHotspot(f: HotspotForm, dev: NM.DeviceWifi): NM.Connection {
  const ap = hotspotCapable(dev)
  const [c, sCon] = baseConnection(HOTSPOT_ID, "802-11-wireless")
  sCon.autoconnect = false
  sCon.interface_name = dev.get_iface()
  const sWifi = new NM.SettingWireless({ ssid: ssidBytes(f.ssid), mode: ap ? "ap" : "adhoc" })
  if (f.band) sWifi.band = f.band
  else if (!ap) sWifi.band = "bg"
  c.add_setting(sWifi)
  c.add_setting(new NM.SettingIP4Config({ method: "shared" }))
  c.add_setting(new NM.SettingIP6Config({ method: "ignore" }))
  // Ad-hoc can't do WPA; it stays open.
  if (ap && f.security !== "none") {
    c.add_setting(new NM.SettingWirelessSecurity({
      key_mgmt: f.security, psk: f.password, proto: ["rsn"], pairwise: ["ccmp"], group: ["ccmp"],
    } as any))
  }
  return c
}

export function existingHotspot(): NM.RemoteConnection | null {
  return client.get_connections().find((c) => c.get_id() === HOTSPOT_ID && isHotspot(c)) ?? null
}

// Start the hotspot, reusing (and updating) our saved "Hotspot" connection.
export async function startHotspot(f: HotspotForm, dev: NM.DeviceWifi) {
  const conn = buildHotspot(f, dev)
  const existing = existingHotspot()
  if (existing) {
    conn.get_setting_connection()!.uuid = existing.get_uuid()
    existing.replace_settings_from_connection(conn)
    await commitConnection(existing)
    await connectAndWait({ conn: existing, device: dev })
  } else {
    const remote = await addConnection(conn)
    await connectAndWait({ conn: remote, device: dev })
  }
}

// ---- join dialog request -----------------------------------------------------------

export type JoinRequest =
  | { kind: "wifi"; device: NM.DeviceWifi | null; form: Partial<WifiForm>; ap?: NM.AccessPoint; lockSsid: boolean }
  | { kind: "hotspot"; device: NM.DeviceWifi }

export const [joinRequest, setJoinRequest] = createState<JoinRequest | null>(null)

// Saved Wi-Fi client connections (for the hidden-network picker).
export function savedWifiConnections(): NM.RemoteConnection[] {
  return client
    .get_connections()
    .filter((c) => c.get_connection_type() === "802-11-wireless" && !isHotspot(c))
    .sort((a, b) => (a.get_id() ?? "").localeCompare(b.get_id() ?? ""))
}

export function submitWifiForm(f: WifiForm, dev: NM.DeviceWifi | null, ap?: NM.AccessPoint): Promise<void> {
  const conn = buildWifiConnection(f)
  const specific = ap ? ap.get_path() : null
  // Forms carry the user's typed settings, so keep the connection even if the
  // first attempt fails (it can be fixed in the editor).
  return connectAndWait({ partial: conn, device: dev, specific, removeOnFailure: false })
}
