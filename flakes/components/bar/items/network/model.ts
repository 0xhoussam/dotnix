import { createExternal, createState, type Accessor } from "ags"
import NM from "gi://NM"
import { apMatches, apSecurity, client, connectAll, deviceConnections, debounce, isListable, ssidText, unbind, type Security } from "./util"

// Wi-Fi network list for one device. Access points sharing SSID + mode +
// security collapse into one WifiNet (nm-applet's duplicate hashing). WifiNet
// objects are reused across updates so rows keep their widgets/expanded state;
// the section arrays only change when membership or order changes.

export class WifiNet {
  aps: NM.AccessPoint[] = []
  connections: NM.RemoteConnection[] = []
  readonly rev: Accessor<number>
  private setRev: (v: number) => void

  constructor(
    readonly key: string,
    readonly ssid: string,
    readonly security: Security,
    readonly mode: number,
    readonly device: NM.DeviceWifi,
  ) {
    const [rev, setRev] = createState(0)
    this.rev = rev
    this.setRev = setRev
  }

  get best(): NM.AccessPoint {
    return this.aps.reduce((a, b) => (b.get_strength() > a.get_strength() ? b : a))
  }

  get strength(): number {
    return this.aps.length ? this.best.get_strength() : 0
  }

  get saved(): boolean {
    return this.connections.length > 0
  }

  bump() {
    this.setRev(this.rev.get() + 1)
  }
}

export interface WifiSections {
  active: WifiNet | null
  saved: WifiNet[]
  other: WifiNet[]
}

const hex = (ap: NM.AccessPoint) =>
  Array.from(ap.get_ssid()?.get_data() ?? [], (b: number) => b.toString(16).padStart(2, "0")).join("")

export const netKey = (ap: NM.AccessPoint) => `${hex(ap)}|${ap.get_mode()}|${apSecurity(ap)}`

const sameKeys = (a: WifiNet[], b: WifiNet[]) => a.length === b.length && a.every((n, i) => n === b[i])

export interface WifiModel {
  sections: Accessor<WifiSections>
  // While frozen (pointer over the list / a row expanded) the order is kept
  // stable, like nm-applet pausing updates while its submenu is open.
  setFrozen: (frozen: boolean) => void
}

export function createWifiModel(dev: NM.DeviceWifi): WifiModel {
  const cache = new Map<string, WifiNet>()
  let frozen = false
  let pending = false
  let last: WifiSections = { active: null, saved: [], other: [] }
  let emit: ((s: WifiSections) => void) | null = null

  const compute = (): WifiSections => {
    const conns = deviceConnections(dev)
    const groups = new Map<string, NM.AccessPoint[]>()
    for (const ap of dev.get_access_points()) {
      if (!isListable(ap)) continue
      const k = netKey(ap)
      const list = groups.get(k)
      list ? list.push(ap) : groups.set(k, [ap])
    }

    for (const k of [...cache.keys()]) if (!groups.has(k)) cache.delete(k)
    for (const [k, aps] of groups) {
      let net = cache.get(k)
      if (!net) {
        net = new WifiNet(k, ssidText(aps[0].get_ssid()), apSecurity(aps[0]), aps[0].get_mode(), dev)
        cache.set(k, net)
      }
      net.aps = aps
      const seen = new Set<string>()
      net.connections = aps
        .flatMap((ap) => conns.filter((c) => apMatches(ap, c)))
        .filter((c) => (seen.has(c.get_uuid()) ? false : (seen.add(c.get_uuid()), true)))
    }

    const activeAp = dev.get_active_access_point()
    const active = activeAp && isListable(activeAp) ? (cache.get(netKey(activeAp)) ?? null) : null
    const rest = [...cache.values()].filter((n) => n !== active).sort((a, b) => b.strength - a.strength)
    return {
      active,
      saved: rest.filter((n) => n.saved),
      other: rest.filter((n) => !n.saved).slice(0, 40),
    }
  }

  const update = () => {
    const next = compute()
    cache.forEach((n) => n.bump())
    const changed =
      next.active !== last.active || !sameKeys(next.saved, last.saved) || !sameKeys(next.other, last.other)
    if (!changed) return
    // Membership changes always apply; only pure re-ordering waits for unfreeze.
    const membership = (s: WifiSections) => new Set([s.active, ...s.saved, ...s.other])
    const a = membership(next)
    const b = membership(last)
    const reorderOnly = a.size === b.size && [...a].every((n) => b.has(n)) && next.active === last.active
    if (frozen && reorderOnly) {
      pending = true
      return
    }
    last = next
    emit?.(next)
  }

  const [schedule, cancel] = debounce(400, update)

  // Computed eagerly: createExternal only notifies subscribers added before a
  // set(), so the producer must not be the one delivering the first value.
  last = compute()

  const sections = createExternal<WifiSections>(last, (set) => {
    emit = set
    const apHandlers = new Map<NM.AccessPoint, number>()
    const watchAp = (ap: NM.AccessPoint) => {
      if (!apHandlers.has(ap)) apHandlers.set(ap, ap.connect("notify::strength", schedule))
    }
    const syncAps = () => {
      const now = new Set(dev.get_access_points())
      for (const [ap, id] of apHandlers) if (!now.has(ap)) (unbind(ap, id), apHandlers.delete(ap))
      now.forEach(watchAp)
    }
    syncAps()
    const offDev = connectAll(
      dev,
      ["access-point-added", "access-point-removed", "notify::active-access-point", "state-changed"],
      () => (syncAps(), schedule()),
    )
    const offClient = connectAll(client, ["connection-added", "connection-removed"], schedule)
    schedule()

    return () => {
      offDev()
      offClient()
      cancel()
      apHandlers.forEach((id, ap) => unbind(ap, id))
      emit = null
    }
  })

  return {
    sections,
    setFrozen(f: boolean) {
      frozen = f
      if (!f && pending) {
        pending = false
        last = { active: null, saved: [], other: [] }
        update()
      }
    },
  }
}
