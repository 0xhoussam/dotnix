import Gio from "gi://Gio"
import GLib from "gi://GLib"
import NM from "gi://NM"
import { clearSecrets, lookupSecrets, storeSecret } from "./keyring"
import { AGENT_CANCEL, USER_CANCEL, askSecrets, cancelSecrets, type SecretField, type SecretPrompt } from "./prompts"
import { client, commitConnection, ssidText } from "./util"
import { VpnCancelled, runAuthDialog } from "./vpn"

// org.freedesktop.NetworkManager.SecretAgent (nm-applet's applet-agent.c):
// NetworkManager calls GetSecrets whenever a connection needs a password it
// doesn't have: first connect to a new network, wrong / changed password
// (REQUEST_NEW), 802.1X, VPN, PPPoE, mobile broadband. Agent-owned secrets
// are kept in the keyring (keyring.ts); system-owned ones NM stores itself.

const AGENT_PATH = "/org/freedesktop/NetworkManager/SecretAgent"
const AGENT_ID = "org.ags.network"
const ERR = "org.freedesktop.NetworkManager.SecretAgent"

const AGENT_XML = `
<node>
  <interface name="org.freedesktop.NetworkManager.SecretAgent">
    <method name="GetSecrets">
      <arg name="connection" type="a{sa{sv}}" direction="in"/>
      <arg name="connection_path" type="o" direction="in"/>
      <arg name="setting_name" type="s" direction="in"/>
      <arg name="hints" type="as" direction="in"/>
      <arg name="flags" type="u" direction="in"/>
      <arg name="secrets" type="a{sa{sv}}" direction="out"/>
    </method>
    <method name="CancelGetSecrets">
      <arg name="connection_path" type="o" direction="in"/>
      <arg name="setting_name" type="s" direction="in"/>
    </method>
    <method name="SaveSecrets">
      <arg name="connection" type="a{sa{sv}}" direction="in"/>
      <arg name="connection_path" type="o" direction="in"/>
    </method>
    <method name="DeleteSecrets">
      <arg name="connection" type="a{sa{sv}}" direction="in"/>
      <arg name="connection_path" type="o" direction="in"/>
    </method>
  </interface>
</node>`

class AgentError extends Error {
  constructor(public code: "NoSecrets" | "UserCanceled" | "AgentCanceled" | "Failed" | "InvalidConnection", msg: string) {
    super(msg)
  }
}

const F = NM.SecretAgentGetSecretsFlags
const AGENT_OWNED = NM.SettingSecretFlags.AGENT_OWNED

type Secrets = Record<string, Record<string, GLib.Variant>>

const strings = (setting: string, obj: Record<string, string>): Secrets => ({
  [setting]: Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, new GLib.Variant("s", v)])),
})

// ---- prompt construction --------------------------------------------------------

const PRINTABLE = /^[\x20-\x7e]*$/
const HEX = /^[0-9a-fA-F]*$/

function validatePsk(v: string) {
  if (v.length === 64 && HEX.test(v)) return null
  if (v.length < 8 || v.length > 63) return "Must be 8–63 characters (or 64 hex digits)"
  if (!PRINTABLE.test(v)) return "Only printable ASCII characters are allowed"
  return null
}

const nonEmpty = (v: string) => (v ? null : "Required")

function validateWepKey(v: string) {
  if ((v.length === 10 || v.length === 26) && HEX.test(v)) return null
  if ((v.length === 5 || v.length === 13) && PRINTABLE.test(v)) return null
  return "WEP keys are 5/13 characters or 10/26 hex digits"
}

const secretOf = (setting: NM.Setting | null, key: string): string | undefined => {
  try {
    const v = (setting as any)?.[key.replace(/-/g, "_")]
    return typeof v === "string" && v ? v : undefined
  } catch {
    return undefined
  }
}

function buildPrompt(conn: NM.Connection, path: string, setting: string, hints: string[], flags: number): SecretPrompt | null {
  const id = conn.get_id()
  const ssid = ssidText(conn.get_setting_wireless()?.get_ssid() ?? null)
  const isWifi = conn.get_connection_type() === "802-11-wireless"
  const note = flags & F.REQUEST_NEW ? "The previous secret was not accepted. Please try again." : undefined
  const fields: SecretField[] = []
  let title = "Authentication Required"
  let message = `Secrets are required to connect to “${id}”.`
  let icon = "dialog-password-symbolic"

  switch (setting) {
    case "802-11-wireless-security": {
      const s = conn.get_setting_wireless_security()
      const km = s?.get_key_mgmt() ?? ""
      title = "Wi-Fi Network Authentication Required"
      message = `Passwords or encryption keys are required to access the Wi-Fi network “${ssid || id}”.`
      icon = "network-wireless-encrypted-symbolic"
      if (flags & F.WPS_PBC_ACTIVE) message += " You can also push the WPS button on your router."
      if (km === "wpa-psk") {
        fields.push({ key: "psk", label: "Password", password: true, value: secretOf(s, "psk"), validate: validatePsk })
      } else if (km === "sae") {
        fields.push({ key: "psk", label: "Password", password: true, value: secretOf(s, "psk"), validate: nonEmpty })
      } else if (s?.get_auth_alg() === "leap") {
        message = `LEAP password for “${s.get_leap_username() ?? ""}” on “${ssid || id}”.`
        fields.push({ key: "leap-password", label: "Password", password: true, validate: nonEmpty })
      } else if (km === "none") {
        const idx = s?.get_wep_tx_keyidx() ?? 0
        const passphrase = s?.get_wep_key_type() === NM.WepKeyType.PASSPHRASE
        fields.push({
          key: `wep-key${idx}`,
          label: passphrase ? "WEP passphrase" : "WEP key",
          password: true,
          value: s?.get_wep_key(idx) ?? undefined,
          validate: passphrase ? (v) => (v && v.length <= 64 ? null : "1–64 characters") : validateWepKey,
        })
      }
      break
    }

    case "802-1x": {
      const s = conn.get_setting_802_1x()
      const eap = s?.get_eap_method(0) ?? ""
      title = isWifi ? "Wi-Fi Network Authentication Required" : "Wired 802.1X Authentication"
      message = isWifi
        ? `Authentication is required to access the Wi-Fi network “${ssid || id}”.`
        : `Authentication is required to access the network “${id}”.`
      icon = isWifi ? "network-wireless-encrypted-symbolic" : "network-wired-symbolic"
      if (eap === "tls") {
        fields.push({ key: "private-key-password", label: "Private key password", password: true })
      } else {
        if (!s?.get_identity()) fields.push({ key: "identity", label: "Username", validate: nonEmpty })
        else message += ` (as ${s.get_identity()})`
        fields.push({ key: "password", label: "Password", password: true, validate: nonEmpty })
      }
      break
    }

    case "pppoe": {
      const s = conn.get_setting_pppoe()
      title = "DSL Authentication"
      message = `A password is required for “${s?.get_username() ?? id}”.`
      icon = "network-wired-symbolic"
      fields.push({ key: "password", label: "Password", password: true })
      break
    }

    case "gsm":
    case "cdma": {
      icon = "network-cellular-symbolic"
      if (hints.includes("pin")) {
        title = "SIM PIN Required"
        message = `The mobile broadband connection “${id}” requires a SIM PIN.`
        fields.push({ key: "pin", label: "PIN code", password: true, validate: (v) => (/^\d{4,8}$/.test(v) ? null : "4–8 digits") })
      } else {
        title = "Mobile Broadband Network Password"
        message = `A password is required to connect to “${id}”.`
        fields.push({ key: "password", label: "Password", password: true })
      }
      break
    }

    case "wireguard":
      title = "WireGuard Key Required"
      message = `The WireGuard connection “${id}” needs its private key.`
      icon = "network-vpn-symbolic"
      fields.push({ key: "private-key", label: "Private key", password: true, validate: nonEmpty })
      break

    default:
      icon = setting === "vpn" ? "network-vpn-symbolic" : icon
      for (const h of hints.filter((h) => !h.startsWith("x-"))) fields.push({ key: h, label: h, password: true })
      if (!fields.length) fields.push({ key: "password", label: "Password", password: true })
  }

  if (!fields.length) return null
  return { path, setting, title, message, icon, fields, note }
}

// ---- request handling ---------------------------------------------------------

interface Pending {
  path: string
  setting: string
  cancelled: boolean
}

const pending = new Set<Pending>()
let queue: Promise<unknown> = Promise.resolve()

// Prompts are shown one after another (several settings can be asked at once).
function serialized<T>(fn: () => Promise<T>): Promise<T> {
  const run = queue.then(fn, fn)
  queue = run.catch(() => {})
  return run
}

async function vpnSecrets(conn: NM.Connection, path: string, hints: string[], flags: number): Promise<Secrets> {
  // Keyring secrets are handed to the auth-dialog, which decides whether it
  // still needs to show UI (same as nm-applet).
  const stored = flags & F.REQUEST_NEW ? {} : await lookupSecrets(conn.get_uuid(), "vpn")
  const sVpn = conn.get_setting_vpn()
  for (const [k, v] of Object.entries(stored)) sVpn?.add_secret(k, v)

  const dialog = runAuthDialog(conn, hints, flags)
  if (!dialog) {
    if (Object.keys(stored).length) return { vpn: { secrets: new GLib.Variant("a{ss}", stored) } }
    if (!(flags & F.ALLOW_INTERACTION)) throw new AgentError("NoSecrets", "No stored VPN secrets")
  }
  if (dialog) {
    try {
      const secrets = await dialog
      return { vpn: { secrets: new GLib.Variant("a{ss}", secrets) } }
    } catch (e) {
      if (e instanceof VpnCancelled) throw new AgentError("UserCanceled", "User cancelled")
      throw new AgentError("Failed", `VPN auth dialog failed: ${e}`)
    }
  }

  // No auth-dialog installed for this plugin: ask for the hinted secrets ourselves.
  const prompt = buildPrompt(conn, path, "vpn", hints, flags)!
  prompt.title = "VPN Password"
  prompt.message = `Secrets are required to connect to the VPN “${conn.get_id()}”.`
  const a = await askSecrets(prompt)
  if (a === USER_CANCEL) throw new AgentError("UserCanceled", "User cancelled")
  if (a === AGENT_CANCEL) throw new AgentError("AgentCanceled", "Cancelled")
  return { vpn: { secrets: new GLib.Variant("a{ss}", a) } }
}

async function getSecrets(connV: GLib.Variant, path: string, setting: string, hints: string[], flags: number) {
  let conn: NM.Connection
  try {
    conn = NM.SimpleConnection.new_from_dbus(connV)
  } catch (e) {
    throw new AgentError("InvalidConnection", String(e))
  }

  const req: Pending = { path, setting, cancelled: false }
  pending.add(req)
  try {
    return await serialized(async () => {
      if (req.cancelled) throw new AgentError("AgentCanceled", "Cancelled")
      if (setting === "vpn") return vpnSecrets(conn, path, hints, flags)

      // Agent-owned secrets we already have in the keyring.
      if (!(flags & F.REQUEST_NEW)) {
        const stored = await lookupSecrets(conn.get_uuid(), setting)
        if (Object.keys(stored).length) return strings(setting, stored)
      }
      if (!(flags & F.ALLOW_INTERACTION)) throw new AgentError("NoSecrets", "No secrets and interaction not allowed")

      const prompt = buildPrompt(conn, path, setting, hints, flags)
      if (!prompt) return {} // nothing to ask (e.g. OWE)

      const a = await askSecrets(prompt)
      if (a === USER_CANCEL) throw new AgentError("UserCanceled", "User cancelled")
      if (a === AGENT_CANCEL) throw new AgentError("AgentCanceled", "Cancelled")

      // 802.1X username isn't a secret: write it into the saved connection.
      const { identity, ...secrets } = a
      if (identity) {
        const remote = client.get_connection_by_path(path)
        const s = remote?.get_setting_802_1x()
        if (remote && s) {
          s.identity = identity
          await commitConnection(remote).catch((e) => console.error("network: saving identity failed:", e))
        }
      }
      return strings(setting, secrets)
    })
  } finally {
    pending.delete(req)
  }
}

// Every secret key libnm knows per setting (the agent only stores
// agent-owned ones).
const SECRET_KEYS: Record<string, string[]> = {
  "802-11-wireless-security": ["psk", "wep-key0", "wep-key1", "wep-key2", "wep-key3", "leap-password"],
  "802-1x": ["password", "private-key-password", "phase2-private-key-password", "pin"],
  pppoe: ["password"],
  gsm: ["password", "pin"],
  cdma: ["password"],
  wireguard: ["private-key"],
}

// Secret flags, read from the "<key>-flags" property. (NM.Setting.get_secret_flags
// has an unannotated out-pointer and can't be called from GJS.) WEP keys share
// one "wep-key-flags"; VPN keeps per-secret flags as "<key>-flags" data items.
function secretFlags(setting: NM.Setting, key: string): number {
  try {
    if (setting instanceof NM.SettingVpn) return parseInt(setting.get_data_item(`${key}-flags`) ?? "0", 10) || 0
    const prop = (/^wep-key\d$/.test(key) ? "wep-key-flags" : `${key}-flags`).replace(/-/g, "_")
    return Number((setting as any)[prop] ?? 0)
  } catch {
    return 0
  }
}

async function saveSecrets(connV: GLib.Variant) {
  const conn = NM.SimpleConnection.new_from_dbus(connV)
  const uuid = conn.get_uuid()
  const id = conn.get_id()
  await clearSecrets(uuid)

  const jobs: Promise<void>[] = []
  for (const [name, keys] of Object.entries(SECRET_KEYS)) {
    const s = conn.get_setting_by_name(name)
    if (!s) continue
    for (const key of keys) {
      const value = secretOf(s, key)
      if (value && secretFlags(s, key) === AGENT_OWNED) jobs.push(storeSecret(uuid, id, name, key, value))
    }
  }
  const vpn = conn.get_setting_vpn()
  vpn?.foreach_secret((key: string, value: string) => {
    if (value && secretFlags(vpn, key) === AGENT_OWNED) jobs.push(storeSecret(uuid, id, "vpn", key, value))
  })
  await Promise.all(jobs)
}

const reply = (inv: Gio.DBusMethodInvocation, p: Promise<unknown>, ok: (v: any) => GLib.Variant | null) =>
  p.then(
    (v) => inv.return_value(ok(v)),
    (e) => {
      if (e instanceof AgentError) inv.return_dbus_error(`${ERR}.${e.code}`, e.message)
      else {
        console.error("network agent:", e)
        inv.return_dbus_error(`${ERR}.Failed`, String(e))
      }
    },
  )

const impl = {
  GetSecretsAsync(_args: unknown, inv: Gio.DBusMethodInvocation) {
    const params = inv.get_parameters()
    const connV = params.get_child_value(0)
    const [, path, setting, hints, flags] = params.deepUnpack() as [unknown, string, string, string[], number]
    void reply(inv, getSecrets(connV, path, setting, hints, flags), (s: Secrets) => new GLib.Variant("(a{sa{sv}})", [s]))
  },

  // (sync handlers get their arguments spread; only *Async ones get an array)
  CancelGetSecrets(path: string, setting: string) {
    for (const r of pending) if (r.path === path && r.setting === setting) r.cancelled = true
    cancelSecrets(path, setting)
  },

  SaveSecretsAsync(_args: unknown, inv: Gio.DBusMethodInvocation) {
    void reply(inv, saveSecrets(inv.get_parameters().get_child_value(0)), () => null)
  },

  DeleteSecretsAsync(_args: unknown, inv: Gio.DBusMethodInvocation) {
    const conn = NM.SimpleConnection.new_from_dbus(inv.get_parameters().get_child_value(0))
    void reply(inv, clearSecrets(conn.get_uuid()), () => null)
  },
}

function agentManagerCall(method: string, params: GLib.Variant | null): Promise<void> {
  return new Promise((resolve, reject) => {
    Gio.DBus.system.call(
      "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager/AgentManager",
      "org.freedesktop.NetworkManager.AgentManager", method, params, null, Gio.DBusCallFlags.NONE, -1, null,
      (c, res) => {
        try {
          c!.call_finish(res)
          resolve()
        } catch (e) {
          reject(e)
        }
      })
  })
}

let exported: Gio.DBusExportedObject | null = null
let watchId = 0

// Export the agent and (re-)register whenever NetworkManager (re)appears.
export function startNetworkAgent() {
  if (exported) return
  exported = Gio.DBusExportedObject.wrapJSObject(AGENT_XML, impl)
  exported.export(Gio.DBus.system, AGENT_PATH)

  watchId = Gio.bus_watch_name(
    Gio.BusType.SYSTEM,
    "org.freedesktop.NetworkManager",
    Gio.BusNameWatcherFlags.NONE,
    () =>
      void agentManagerCall("RegisterWithCapabilities",
        new GLib.Variant("(su)", [AGENT_ID, NM.SecretAgentCapabilities.VPN_HINTS]))
        .catch((e) => console.error("network: agent registration failed:", e)),
    () => cancelSecrets(),
  )
}

export function stopNetworkAgent() {
  if (!exported) return
  if (watchId) Gio.bus_unwatch_name(watchId)
  watchId = 0
  agentManagerCall("Unregister", null).catch(() => {})
  exported.unexport()
  exported = null
}
