import Gio from "gi://Gio"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth"

const AGENT_PATH = "/org/bluez/agent/ags"

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
</node>
`

interface AgentUI {
  askPin(devicePath: string): Promise<string | null>
  askPasskey(devicePath: string): Promise<number | null>
  showPinCode(devicePath: string, pincode: string): void
  showPasskey(devicePath: string, passkey: number, entered: number): void
  requestConfirmation(devicePath: string, passkey: number): Promise<boolean>
  requestAuthorization(devicePath: string): Promise<boolean>
  authorizeService(devicePath: string, uuid: string): Promise<"always" | "accept" | "deny">
  close(): void
  trustDevice(devicePath: string): void
}

let currentUI: AgentUI | null = null
let currentRequestId = 0

function devicePathToAddress(path: string): string {
  const prefix = "/org/bluez/"
  const devPrefix = "dev_"
  const idx = path.indexOf(devPrefix)
  if (idx === -1) return path
  const addrPart = path.slice(idx + devPrefix.length)
  return addrPart.split("_").join(":").toUpperCase()
}

function getDeviceByPath(path: string): AstalBluetooth.Device | null {
  const bt = AstalBluetooth.get_default()
  const address = devicePathToAddress(path)
  return bt.devices.find(d => d.address === address) || null
}

function deviceDisplayName(path: string): string {
  const dev = getDeviceByPath(path)
  const addr = devicePathToAddress(path)
  return dev?.name ? `${dev.name} (${addr})` : addr
}

function reject(inv: Gio.DBusMethodInvocation) {
  inv.return_dbus_error("org.bluez.Error.Rejected", "Rejected")
}

function cancelPendingRequest() {
  currentRequestId++
  currentUI?.close()
}

const agentImpl = {
  Release() {},

  Cancel() {
    cancelPendingRequest()
  },

  async RequestPinCodeAsync([devPath]: [string], inv: Gio.DBusMethodInvocation) {
    const reqId = ++currentRequestId
    const pin = await currentUI?.askPin(devPath)
    if (reqId !== currentRequestId) return
    pin ? inv.return_value(new GLib.Variant("(s)", [pin])) : reject(inv)
  },

  async RequestPasskeyAsync([devPath]: [string], inv: Gio.DBusMethodInvocation) {
    const reqId = ++currentRequestId
    const key = await currentUI?.askPasskey(devPath)
    if (reqId !== currentRequestId) return
    key !== null && key !== undefined
      ? inv.return_value(new GLib.Variant("(u)", [key]))
      : reject(inv)
  },

  DisplayPinCode([devPath, pincode]: [string, string]) {
    currentUI?.showPinCode(devPath, pincode)
  },

  DisplayPasskey([devPath, passkey, entered]: [string, number, number]) {
    currentUI?.showPasskey(devPath, passkey, entered)
  },

  async RequestConfirmationAsync([devPath, passkey]: [string, number], inv: Gio.DBusMethodInvocation) {
    const reqId = ++currentRequestId
    const ok = await currentUI?.requestConfirmation(devPath, passkey)
    if (reqId !== currentRequestId) return
    ok ? inv.return_value(null) : reject(inv)
  },

  async RequestAuthorizationAsync([devPath]: [string], inv: Gio.DBusMethodInvocation) {
    const reqId = ++currentRequestId
    const ok = await currentUI?.requestAuthorization(devPath)
    if (reqId !== currentRequestId) return
    ok ? inv.return_value(null) : reject(inv)
  },

  async AuthorizeServiceAsync([devPath, uuid]: [string, string], inv: Gio.DBusMethodInvocation) {
    const reqId = ++currentRequestId
    const result = await currentUI?.authorizeService(devPath, uuid)
    if (reqId !== currentRequestId) return
    if (result === "always") currentUI?.trustDevice(devPath)
    result === "deny" ? reject(inv) : inv.return_value(null)
  },
}

export function registerBluetoothAgent(ui: AgentUI) {
  if (currentUI) {
    console.warn("Bluetooth agent already registered")
    return
  }

  currentUI = ui

  const exported = Gio.DBusExportedObject.wrapJSObject(AGENT_XML, agentImpl)
  exported.export(Gio.DBus.system, AGENT_PATH)

  Gio.DBus.system.call(
    "org.bluez",
    "/org/bluez",
    "org.bluez.AgentManager1",
    "RegisterAgent",
    new GLib.Variant("(os)", [AGENT_PATH, "KeyboardDisplay"]),
    null,
    Gio.DBusCallFlags.NONE,
    -1,
    null,
    (conn, res) => {
      try {
        conn.call_finish(res)
        Gio.DBus.system.call(
          "org.bluez",
          "/org/bluez",
          "org.bluez.AgentManager1",
          "RequestDefaultAgent",
          new GLib.Variant("(o)", [AGENT_PATH]),
          null,
          Gio.DBusCallFlags.NONE,
          -1,
          null,
          () => {},
        )
      } catch (e) {
        console.error("Failed to register Bluetooth agent:", e)
      }
    },
  )
}

export function unregisterBluetoothAgent() {
  if (!currentUI) return
  currentUI = null
  try {
    Gio.DBus.system.call(
      "org.bluez",
      "/org/bluez",
      "org.bluez.AgentManager1",
      "UnregisterAgent",
      new GLib.Variant("(o)", [AGENT_PATH]),
      null,
      Gio.DBusCallFlags.NONE,
      -1,
      null,
      () => {},
    )
  } catch (e) {
    console.error("Failed to unregister Bluetooth agent:", e)
  }
}

export function isAgentRegistered(): boolean {
  return currentUI !== null
}