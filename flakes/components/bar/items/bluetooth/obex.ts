import Gio from "gi://Gio"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth"
import { Gtk } from "ags/gtk4"
import { createState } from "ags"
import { ask } from "./prompts"
import { deviceByAddress, devicePath, displayName, formatBytes, notify, sessionCall, settings } from "./util"

// OBEX object push via obexd (session bus): an org.bluez.obex.Agent1 that
// accepts incoming files into ~/Downloads, plus sending files to a device.

const OBEX = "org.bluez.obex"
const AGENT_PATH = "/org/ags/bluetooth/obex_agent"
const PROPS = "org.freedesktop.DBus.Properties"

const AGENT_XML = `
<node>
  <interface name="org.bluez.obex.Agent1">
    <method name="Release"/>
    <method name="AuthorizePush">
      <arg type="o" name="transfer" direction="in"/>
      <arg type="s" name="filename" direction="out"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>`

export interface Transfer {
  path: string
  direction: "in" | "out"
  name: string
  device: string // display name
  size: number
  transferred: number
  status: string // queued | active | suspended | complete | error
}

export const [transfers, setTransfers] = createState<Transfer[]>([])

function upsert(path: string, patch: Partial<Transfer>) {
  const list = transfers.get()
  const i = list.findIndex((t) => t.path === path)
  if (i === -1) setTransfers([...list, patch as Transfer])
  else setTransfers(list.map((t, j) => (j === i ? { ...t, ...patch } : t)))
}

function drop(path: string) {
  setTransfers(transfers.get().filter((t) => t.path !== path))
}

async function getAll(path: string, iface: string): Promise<Record<string, any>> {
  const res = await sessionCall(OBEX, path, PROPS, "GetAll", new GLib.Variant("(s)", [iface]))
  return (res.recursiveUnpack() as [Record<string, any>])[0]
}

// Follow a Transfer1 object until it completes or fails.
function watchTransfer(path: string, onDone: (ok: boolean) => void) {
  let done = false
  const id = Gio.DBus.session.signal_subscribe(
    OBEX, PROPS, "PropertiesChanged", path, "org.bluez.obex.Transfer1",
    Gio.DBusSignalFlags.NONE,
    (_c, _s, _p, _i, _m, params) => {
      const [, changed] = params.recursiveUnpack() as [string, Record<string, any>]
      const patch: Partial<Transfer> = {}
      if ("Transferred" in changed) patch.transferred = Number(changed.Transferred)
      if ("Size" in changed) patch.size = Number(changed.Size)
      if ("Status" in changed) patch.status = changed.Status
      upsert(path, patch)
      if (!done && (changed.Status === "complete" || changed.Status === "error")) {
        done = true
        Gio.DBus.session.signal_unsubscribe(id)
        onDone(changed.Status === "complete")
      }
    },
  )
}

export function cancelTransfer(path: string) {
  sessionCall(OBEX, path, "org.bluez.obex.Transfer1", "Cancel").catch(() => {})
}

// ---- receiving ----------------------------------------------------------------

const allowedFor = new Map<string, number>() // address -> expiry (ms); recently accepted

function downloadDir(): string {
  return GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DOWNLOAD)
    ?? GLib.build_filenamev([GLib.get_home_dir(), "Downloads"])
}

function uniqueDest(dir: string, name: string): string {
  let dest = GLib.build_filenamev([dir, name])
  if (!GLib.file_test(dest, GLib.FileTest.EXISTS)) return dest
  const dot = name.lastIndexOf(".")
  const [base, ext] = dot > 0 ? [name.slice(0, dot), name.slice(dot)] : [name, ""]
  for (let i = 1; ; i++) {
    dest = GLib.build_filenamev([dir, `${base} (${i})${ext}`])
    if (!GLib.file_test(dest, GLib.FileTest.EXISTS)) return dest
  }
}

function finishIncoming(tmp: string, name: string, from: string, ok: boolean) {
  if (!ok) {
    void notify("Transfer failed", `${name} from ${from}`, "dialog-error-symbolic")
    return
  }
  const dir = downloadDir()
  GLib.mkdir_with_parents(dir, 0o755)
  const dest = uniqueDest(dir, GLib.path_get_basename(name))
  try {
    Gio.File.new_for_path(tmp).move(Gio.File.new_for_path(dest), Gio.FileCopyFlags.NONE, null, null)
    void notify("File received", `${GLib.path_get_basename(dest)} from ${from}\nSaved to ${dir}`, "document-save-symbolic")
  } catch (e) {
    console.error("bluetooth: moving received file failed:", e)
    void notify("File received", `${name} from ${from}\nLeft at ${tmp}`, "document-save-symbolic")
  }
}

const agentImpl = {
  Release() {},
  Cancel() {},

  async AuthorizePushAsync([path]: [string], inv: Gio.DBusMethodInvocation) {
    try {
      const t = await getAll(path, "org.bluez.obex.Transfer1")
      const s = await getAll(t.Session, "org.bluez.obex.Session1")
      const address = String(s.Destination ?? "")
      const dev = deviceByAddress(address)
      const from = displayName(dev, address)
      const name = String(t.Name || "file")
      const size = Number(t.Size ?? 0)

      const recentlyAllowed = (allowedFor.get(address) ?? 0) > Date.now()
      const autoAccept = recentlyAllowed || (settings.get().acceptFromTrusted && dev?.trusted)
      if (!autoAccept) {
        const a = await ask({ kind: "file", path: dev ? devicePath(dev) : path, name, size })
        if (a !== true) {
          inv.return_dbus_error("org.bluez.obex.Error.Rejected", "Rejected by user")
          return
        }
      }
      // further files in the same batch go through silently for a minute
      allowedFor.set(address, Date.now() + 60_000)

      const root = String(s.Root || GLib.get_user_cache_dir())
      const tmp = GLib.build_filenamev([root, GLib.path_get_basename(name)])
      upsert(path, { path, direction: "in", name, device: from, size, transferred: 0, status: "queued" })
      watchTransfer(path, (ok) => {
        drop(path)
        finishIncoming(tmp, name, from, ok)
      })
      inv.return_value(new GLib.Variant("(s)", [tmp]))
    } catch (e) {
      console.error("bluetooth: AuthorizePush failed:", e)
      inv.return_dbus_error("org.bluez.obex.Error.Rejected", String(e))
    }
  },
}

let exported: Gio.DBusExportedObject | null = null
let watchId = 0

export function startObexAgent() {
  if (exported) return
  exported = Gio.DBusExportedObject.wrapJSObject(AGENT_XML, agentImpl)
  exported.export(Gio.DBus.session, AGENT_PATH)

  // obexd is D-Bus activated; AUTO_START spawns it so we can register.
  watchId = Gio.bus_watch_name(
    Gio.BusType.SESSION, OBEX, Gio.BusNameWatcherFlags.AUTO_START,
    () => {
      sessionCall(OBEX, "/org/bluez/obex", "org.bluez.obex.AgentManager1", "RegisterAgent",
        new GLib.Variant("(o)", [AGENT_PATH]))
        .catch((e) => console.warn("bluetooth: OBEX RegisterAgent failed:", e))
    },
    () => setTransfers([]),
  )
}

export function stopObexAgent() {
  if (!exported) return
  if (watchId) Gio.bus_unwatch_name(watchId)
  watchId = 0
  sessionCall(OBEX, "/org/bluez/obex", "org.bluez.obex.AgentManager1", "UnregisterAgent",
    new GLib.Variant("(o)", [AGENT_PATH])).catch(() => {})
  exported.unexport()
  exported = null
}

// ---- sending -----------------------------------------------------------------

async function sendFiles(device: AstalBluetooth.Device, files: string[]) {
  const to = displayName(device)
  let session = ""
  try {
    const res = await sessionCall(OBEX, "/org/bluez/obex", "org.bluez.obex.Client1", "CreateSession",
      new GLib.Variant("(sa{sv})", [device.address, { Target: new GLib.Variant("s", "opp") }]), 60_000)
    session = (res.deepUnpack() as [string])[0]

    let sent = 0
    for (const file of files) {
      const name = GLib.path_get_basename(file)
      const r = await sessionCall(OBEX, session, "org.bluez.obex.ObjectPush1", "SendFile",
        new GLib.Variant("(s)", [file]))
      const [tpath, props] = r.recursiveUnpack() as [string, Record<string, any>]
      upsert(tpath, {
        path: tpath, direction: "out", name, device: to,
        size: Number(props.Size ?? 0), transferred: 0, status: String(props.Status ?? "queued"),
      })
      // obexd queues pushes per session; wait for each before the next
      const ok = await new Promise<boolean>((resolve) => watchTransfer(tpath, resolve))
      drop(tpath)
      if (ok) sent++
      else void notify("Sending failed", `${name} to ${to}`, "dialog-error-symbolic")
    }
    if (sent) void notify("Files sent", `${sent} file${sent > 1 ? "s" : ""} sent to ${to}`, "document-send-symbolic")
  } catch (e) {
    void notify("Sending failed", `${to}: ${String((e as any)?.message ?? e).replace(/^GDBus\.Error:[\w.]+:\s*/, "")}`,
      "dialog-error-symbolic")
  } finally {
    if (session)
      sessionCall(OBEX, "/org/bluez/obex", "org.bluez.obex.Client1", "RemoveSession",
        new GLib.Variant("(o)", [session])).catch(() => {})
  }
}

// Pick files with the portal-backed GTK file dialog, then push them.
export function pickAndSend(device: AstalBluetooth.Device) {
  const dialog = new Gtk.FileDialog({ title: `Send files to ${displayName(device)}`, modal: true })
  dialog.open_multiple(null, null, (_d, res) => {
    try {
      const model = dialog.open_multiple_finish(res)
      if (!model) return
      const files: string[] = []
      for (let i = 0; i < model.get_n_items(); i++) {
        const f = model.get_item(i) as Gio.File
        const p = f.get_path()
        if (p) files.push(p)
      }
      if (files.length) void sendFiles(device, files)
    } catch {
      // dismissed
    }
  })
}

export const transferLabel = (t: Transfer) =>
  `${t.direction === "in" ? "↓" : "↑"} ${t.name} · ${t.device}` +
  (t.size ? ` · ${formatBytes(t.transferred)} / ${formatBytes(t.size)}` : "")
