import GLib from "gi://GLib"
import NM from "gi://NM"
import {
  activeReasonText, apMatches, client, deviceConnections, connectAll, deviceReasonText, deviceTypeIcon, isHotspot, isListable, notify, openUri,
  settings, ssidText, unbind, updateSettings,
} from "./util"

// nm-applet's notifications: connection established / disconnected / failed,
// VPN login banner + failure reasons, "Wi-Fi Networks Available", and a
// captive-portal sign-in prompt.

const disposers: (() => void)[] = []
const deviceHandlers = new Map<NM.Device, () => void>()
const vpnHandlers = new Map<NM.ActiveConnection, () => void>()

// Disconnect reasons that aren't worth telling the user about.
const QUIET = new Set<number>([
  NM.DeviceStateReason.USER_REQUESTED,
  NM.DeviceStateReason.CONNECTION_REMOVED,
  NM.DeviceStateReason.NEW_ACTIVATION,
  NM.DeviceStateReason.SLEEPING,
  NM.DeviceStateReason.REMOVED,
  NM.DeviceStateReason.NOW_UNMANAGED,
  NM.DeviceStateReason.NETWORKING_OFF,
  NM.DeviceStateReason.UNMANAGED_SLEEPING,
  NM.DeviceStateReason.UNMANAGED_QUITTING,
])

function onDeviceState(dev: NM.Device, ns: number, os: number, reason: number) {
  const S = NM.DeviceState
  const s = settings.get()
  const conn = dev.get_active_connection()?.get_connection() ?? null

  if (ns === S.ACTIVATED) {
    if (!s.notifyConnected || isHotspot(conn)) return
    const ap = dev instanceof NM.DeviceWifi ? dev.get_active_access_point() : null
    const body = ap
      ? `You are now connected to the Wi-Fi network “${ssidText(ap.get_ssid())}”.`
      : `You are now connected to “${conn?.get_id() ?? dev.get_iface()}”.`
    void notify("Connection Established", body, deviceTypeIcon(dev), { transient: true })
    return
  }

  if (ns === S.FAILED && s.notifyDisconnected) {
    void notify("Connection Failed", deviceReasonText(reason), "network-error-symbolic", { transient: true })
    return
  }

  if (os === S.ACTIVATED && (ns === S.DISCONNECTED || ns === S.UNAVAILABLE) && s.notifyDisconnected && !QUIET.has(reason)) {
    const why = reason ? deviceReasonText(reason) : ""
    void notify("Disconnected", why ? `The network connection has been disconnected: ${why}.` :
      "The network connection has been disconnected.", "network-offline-symbolic", { transient: true })
  }

  if (ns === S.DISCONNECTED && dev instanceof NM.DeviceWifi) queueAvailableCheck(dev)
}

// ---- VPN ---------------------------------------------------------------------------

function watchVpn(ac: NM.ActiveConnection) {
  if (vpnHandlers.has(ac)) return
  const isVpn = ac instanceof NM.VpnConnection
  const isWg = ac.get_connection_type() === "wireguard"
  if (!isVpn && !isWg) return

  const id = ac.get_id()
  const fail = (reason: number, starting: boolean) => {
    if (!settings.get().notifyVpn) return
    const why = activeReasonText(reason)
    void notify(
      starting ? "VPN Connection Failed" : "VPN Disconnected",
      `The VPN connection “${id}” ${starting ? "failed" : "disconnected"}: ${why}.`,
      "network-vpn-disconnected-symbolic",
    )
  }

  let wasActive = false
  const handler = isVpn
    ? ac.connect("vpn-state-changed", (_a: NM.VpnConnection, state: number, reason: number) => {
        const V = NM.VpnConnectionState
        if (state === V.ACTIVATED) {
          wasActive = true
          if (!settings.get().notifyVpn) return
          const banner = (ac as NM.VpnConnection).get_banner()
          void notify(
            banner ? "VPN Login Message" : "VPN Connected",
            banner ? `VPN connection has been successfully established.\n\n${banner}` :
              `VPN connection “${id}” has been successfully established.`,
            "network-vpn-symbolic",
          )
        } else if (state === V.FAILED || state === V.DISCONNECTED) {
          if (reason !== NM.ActiveConnectionStateReason.USER_DISCONNECTED) fail(reason, !wasActive)
        }
      })
    : ac.connect("state-changed", (_a: NM.ActiveConnection, state: number, reason: number) => {
        const A = NM.ActiveConnectionState
        if (state === A.ACTIVATED) {
          wasActive = true
          if (settings.get().notifyVpn)
            void notify("VPN Connected", `WireGuard connection “${id}” is active.`, "network-vpn-symbolic", { transient: true })
        } else if (state === A.DEACTIVATED && reason !== NM.ActiveConnectionStateReason.USER_DISCONNECTED) {
          fail(reason, !wasActive)
        }
      })
  vpnHandlers.set(ac, () => unbind(ac, handler))
}

function syncActive() {
  const now = new Set(client.get_active_connections())
  for (const [ac, off] of vpnHandlers) if (!now.has(ac)) (off(), vpnHandlers.delete(ac))
  now.forEach(watchVpn)
}

// ---- "Wi-Fi Networks Available" ------------------------------------------------------

const AVAILABLE_INTERVAL_US = 15 * 60 * 1_000_000
let lastAvailable = 0
let availableTimer = 0

function queueAvailableCheck(dev: NM.DeviceWifi) {
  if (availableTimer) return
  // wait a bit: NM usually autoconnects to a known network right away
  availableTimer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 8, () => {
    availableTimer = 0
    checkAvailable(dev)
    return GLib.SOURCE_REMOVE
  })
}

function checkAvailable(dev: NM.DeviceWifi) {
  if (!settings.get().notifyAvailable) return
  if (dev.get_state() !== NM.DeviceState.DISCONNECTED) return
  if (client.get_primary_connection()) return
  const now = GLib.get_monotonic_time()
  if (lastAvailable && now - lastAvailable < AVAILABLE_INTERVAL_US) return

  const aps = dev.get_access_points().filter(isListable)
  if (!aps.length) return
  // A saved network in range means NM will autoconnect on its own.
  const conns = deviceConnections(dev)
  if (aps.some((ap) => conns.some((c) => apMatches(ap, c)))) return

  lastAvailable = now
  void notify("Wi-Fi Networks Available", "Use the network menu to connect to a Wi-Fi network.",
    "network-wireless-symbolic", {
      actions: [["dont-show", "Don't show this message again"]],
      onAction: (a) => a === "dont-show" && updateSettings({ notifyAvailable: false }),
    })
}

// ---- captive portal -------------------------------------------------------------------

let portalNotified = false

export function portalUri(): string {
  try {
    return client.connectivity_check_get_uri() || "http://nmcheck.gnome.org/"
  } catch {
    return "http://nmcheck.gnome.org/"
  }
}

function onConnectivity() {
  if (client.get_connectivity() !== NM.ConnectivityState.PORTAL) {
    portalNotified = false
    return
  }
  if (portalNotified) return
  portalNotified = true
  const id = client.get_primary_connection()?.get_id() ?? "this network"
  void notify("Sign in to Network", `You must log in to access the internet on “${id}”.`,
    "network-wireless-no-route-symbolic", {
      actions: [["default", "Sign in"]],
      onAction: () => openUri(portalUri()),
    })
}

// ---- lifecycle ------------------------------------------------------------------------

function watchDevice(dev: NM.Device) {
  if (deviceHandlers.has(dev)) return
  const id = dev.connect("state-changed", (d: NM.Device, ns: number, os: number, reason: number) =>
    onDeviceState(d, ns, os, reason))
  deviceHandlers.set(dev, () => unbind(dev, id))
}

function syncDevices() {
  const now = new Set(client.get_devices())
  for (const [d, off] of deviceHandlers) if (!now.has(d)) (off(), deviceHandlers.delete(d))
  now.forEach(watchDevice)
}

export function startNetworkServices() {
  if (disposers.length) return
  syncDevices()
  syncActive()
  disposers.push(connectAll(client, ["device-added", "device-removed"], syncDevices))
  disposers.push(connectAll(client, ["notify::active-connections"], syncActive))
  disposers.push(connectAll(client, ["notify::connectivity"], onConnectivity))
}

export function stopNetworkServices() {
  disposers.splice(0).forEach((d) => d())
  deviceHandlers.forEach((off) => off())
  deviceHandlers.clear()
  vpnHandlers.forEach((off) => off())
  vpnHandlers.clear()
  if (availableTimer) GLib.source_remove(availableTimer)
  availableTimer = 0
}
