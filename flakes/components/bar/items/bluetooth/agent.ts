import Gio from "gi://Gio"
import GLib from "gi://GLib"
import { ask, show, cancelCurrent, CANCEL, type Answer } from "./prompts"
import { deviceByPath, systemCall } from "./util"

// org.bluez.Agent1: answers BlueZ's pairing / authorization questions by
// showing PairingDialog. Every method call gets exactly one reply.

const AGENT_PATH = "/org/ags/bluetooth/agent"

const AGENT_XML = `
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode">
      <arg type="o" name="device" direction="in"/>
      <arg type="s" name="pincode" direction="out"/>
    </method>
    <method name="DisplayPinCode">
      <arg type="o" name="device" direction="in"/>
      <arg type="s" name="pincode" direction="in"/>
    </method>
    <method name="RequestPasskey">
      <arg type="o" name="device" direction="in"/>
      <arg type="u" name="passkey" direction="out"/>
    </method>
    <method name="DisplayPasskey">
      <arg type="o" name="device" direction="in"/>
      <arg type="u" name="passkey" direction="in"/>
      <arg type="q" name="entered" direction="in"/>
    </method>
    <method name="RequestConfirmation">
      <arg type="o" name="device" direction="in"/>
      <arg type="u" name="passkey" direction="in"/>
    </method>
    <method name="RequestAuthorization">
      <arg type="o" name="device" direction="in"/>
    </method>
    <method name="AuthorizeService">
      <arg type="o" name="device" direction="in"/>
      <arg type="s" name="uuid" direction="in"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>`

function refuse(inv: Gio.DBusMethodInvocation, a: Answer) {
  if (a === CANCEL) inv.return_dbus_error("org.bluez.Error.Canceled", "Canceled by user")
  else inv.return_dbus_error("org.bluez.Error.Rejected", "Rejected by user")
}

const impl = {
  Release() {
    cancelCurrent()
  },

  Cancel() {
    cancelCurrent()
  },

  async RequestPinCodeAsync([path]: [string], inv: Gio.DBusMethodInvocation) {
    const a = await ask({ kind: "pin", path })
    if (typeof a === "string" && a) inv.return_value(new GLib.Variant("(s)", [a]))
    else refuse(inv, a)
  },

  async RequestPasskeyAsync([path]: [string], inv: Gio.DBusMethodInvocation) {
    const a = await ask({ kind: "passkey", path })
    if (typeof a === "number") inv.return_value(new GLib.Variant("(u)", [a]))
    else refuse(inv, a)
  },

  // Sync handlers get their arguments spread; only *Async ones get an array.
  DisplayPinCode(path: string, pin: string) {
    show({ kind: "show-pin", path, pin })
  },

  DisplayPasskey(path: string, passkey: number, entered: number) {
    show({ kind: "show-passkey", path, passkey, entered })
  },

  async RequestConfirmationAsync([path, passkey]: [string, number], inv: Gio.DBusMethodInvocation) {
    const a = await ask({ kind: "confirm", path, passkey })
    if (a === true) inv.return_value(null)
    else refuse(inv, a)
  },

  async RequestAuthorizationAsync([path]: [string], inv: Gio.DBusMethodInvocation) {
    const a = await ask({ kind: "authorize", path })
    if (a === true) inv.return_value(null)
    else refuse(inv, a)
  },

  async AuthorizeServiceAsync([path, uuid]: [string, string], inv: Gio.DBusMethodInvocation) {
    const a = await ask({ kind: "service", path, uuid })
    if (a === "always") {
      const dev = deviceByPath(path)
      if (dev) dev.trusted = true
    }
    if (a === true || a === "always") inv.return_value(null)
    else refuse(inv, a)
  },
}

let exported: Gio.DBusExportedObject | null = null
let watchId = 0

async function register() {
  try {
    await systemCall("/org/bluez", "org.bluez.AgentManager1", "RegisterAgent",
      new GLib.Variant("(os)", [AGENT_PATH, "KeyboardDisplay"]))
  } catch (e) {
    // AlreadyExists after a bluetoothd hiccup is fine
    if (!String(e).includes("AlreadyExists")) {
      console.error("bluetooth: RegisterAgent failed:", e)
      return
    }
  }
  try {
    await systemCall("/org/bluez", "org.bluez.AgentManager1", "RequestDefaultAgent",
      new GLib.Variant("(o)", [AGENT_PATH]))
  } catch (e) {
    console.error("bluetooth: RequestDefaultAgent failed:", e)
  }
}

// Export the agent and (re-)register it whenever bluetoothd (re)appears.
export function startAgent() {
  if (exported) return
  exported = Gio.DBusExportedObject.wrapJSObject(AGENT_XML, impl)
  exported.export(Gio.DBus.system, AGENT_PATH)

  watchId = Gio.bus_watch_name(
    Gio.BusType.SYSTEM,
    "org.bluez",
    Gio.BusNameWatcherFlags.NONE,
    () => void register(),
    () => cancelCurrent(),
  )
}

export function stopAgent() {
  if (!exported) return
  if (watchId) Gio.bus_unwatch_name(watchId)
  watchId = 0
  systemCall("/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent",
    new GLib.Variant("(o)", [AGENT_PATH])).catch(() => {})
  exported.unexport()
  exported = null
}
