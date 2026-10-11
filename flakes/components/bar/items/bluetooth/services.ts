import Gio from "gi://Gio"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth"
import { cancelCurrent } from "./prompts"
import {
  batteryPct, connectDevice, deviceIcon, devicePath, displayName, isGameController, notify, settings,
} from "./util"

// Background behaviour ported from blueman's applet plugins:
// ConnectionNotifier, battery warnings, AutoConnect, GameControllerWakelock.

const LOW_BATTERY = 15

const bt = AstalBluetooth.get_default()
const handlers = new Map<AstalBluetooth.Device, number[]>()
const connectNotif = new Map<string, number>() // address -> notification id
const lowWarned = new Set<string>()

// ---- per-device watchers --------------------------------------------------------

function onConnectedChanged(d: AstalBluetooth.Device) {
  if (d.connected) cancelCurrent(devicePath(d)) // stale pairing prompt
  updateWakelock()
  if (!settings.get().notifyConnections) return
  const name = displayName(d)
  if (d.connected) {
    const pct = batteryPct(d.batteryPercentage)
    void notify(name, pct >= 0 ? `Connected · battery ${pct}%` : "Connected", deviceIcon(d), { transient: true })
      .then((id) => {
        connectNotif.set(d.address, id)
        // Battery usually shows up a moment after connecting; fold it in.
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 15_000, () => {
          connectNotif.delete(d.address)
          return GLib.SOURCE_REMOVE
        })
      })
  } else {
    connectNotif.delete(d.address)
    void notify(name, "Disconnected", deviceIcon(d), { transient: true })
  }
}

function onBatteryChanged(d: AstalBluetooth.Device) {
  const pct = batteryPct(d.batteryPercentage)
  if (pct < 0) return

  const id = connectNotif.get(d.address)
  if (id && settings.get().notifyConnections) {
    connectNotif.delete(d.address)
    void notify(displayName(d), `Connected · battery ${pct}%`, deviceIcon(d), { replaces: id, transient: true })
  }

  if (pct > LOW_BATTERY + 5) lowWarned.delete(d.address)
  else if (pct <= LOW_BATTERY && d.connected && !lowWarned.has(d.address)) {
    lowWarned.add(d.address)
    if (settings.get().notifyLowBattery)
      void notify(`${displayName(d)} battery low`, `${pct}% remaining`, "battery-caution-symbolic", { urgency: 2 })
  }
}

function watch(d: AstalBluetooth.Device) {
  if (handlers.has(d)) return
  handlers.set(d, [
    d.connect("notify::connected", () => onConnectedChanged(d)),
    d.connect("notify::battery-percentage", () => onBatteryChanged(d)),
  ])
}

function unwatch(d: AstalBluetooth.Device) {
  handlers.get(d)?.forEach((id) => d.disconnect(id))
  handlers.delete(d)
  updateWakelock()
}

// ---- game controller idle inhibitor -------------------------------------------
// While a controller is connected, hold a logind idle inhibitor so hypridle
// doesn't dim/lock mid-game.

let inhibitor: Gio.Subprocess | null = null

export function updateWakelock() {
  const want = settings.get().controllerWakelock && bt.devices.some((d) => d.connected && isGameController(d))
  if (want && !inhibitor) {
    try {
      inhibitor = Gio.Subprocess.new(
        ["systemd-inhibit", "--what=idle", "--who=Bluetooth", "--why=Game controller connected",
          "--mode=block", "sleep", "infinity"],
        Gio.SubprocessFlags.NONE,
      )
    } catch (e) {
      console.error("bluetooth: systemd-inhibit failed:", e)
    }
  } else if (!want && inhibitor) {
    inhibitor.force_exit()
    inhibitor = null
  }
}

// ---- auto-connect ----------------------------------------------------------------
// Devices flagged in the device panel are connected when the adapter powers on
// and retried every minute while powered (blueman's AutoConnect plugin).

const inFlight = new Set<string>()

function autoConnect() {
  if (!bt.isPowered) return
  for (const address of settings.get().autoConnect) {
    const d = bt.devices.find((x) => x.address === address)
    if (!d || !d.paired || d.connected || d.connecting || inFlight.has(address)) continue
    inFlight.add(address)
    connectDevice(d)
      .catch(() => {}) // device off / out of range: try again next round
      .finally(() => inFlight.delete(address))
  }
}

// ---- entry point -------------------------------------------------------------------

let started = false

export function startBluetoothServices() {
  if (started) return
  started = true

  bt.devices.forEach(watch)
  bt.connect("device-added", (_bt, d) => watch(d))
  bt.connect("device-removed", (_bt, d) => unwatch(d))

  bt.connect("notify::is-powered", () => {
    if (bt.isPowered) GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => (autoConnect(), GLib.SOURCE_REMOVE))
  })
  GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 60, () => (autoConnect(), GLib.SOURCE_CONTINUE))
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, () => (autoConnect(), GLib.SOURCE_REMOVE))

  settings.subscribe(updateWakelock)
  updateWakelock()
}

export function stopBluetoothServices() {
  inhibitor?.force_exit()
  inhibitor = null
}
