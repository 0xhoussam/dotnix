import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createState, For, With, onCleanup, type Accessor } from "ags"
import GLib from "gi://GLib"
import NM from "gi://NM"
import { InfoPanel } from "./InfoPanel"
import { connectAndWait, setJoinRequest, type SecKind } from "./connections"
import type { WifiNet } from "./model"
import {
  AP_MODE_ADHOC, SECURITY_LABEL, band, canModifySystem, channel, client, connectivityText, deleteConnection,
  deviceStateText, disconnectDevice, errorText, isManufacturerDefault, isSecured, needsForm, openEditor, ssidBytes,
  strengthIcon, type Security,
} from "./util"

export type Expanded = [Accessor<string | null>, (v: string | null) => void]

// Busy label + transient error for one row.
export function createRowOps() {
  const [busy, setBusy] = createState<string | null>(null)
  const [error, setError] = createState<string | null>(null)
  let timer = 0
  const clearTimer = () => timer && GLib.source_remove(timer)
  onCleanup(clearTimer)

  const showError = (msg: string) => {
    setError(msg)
    clearTimer()
    timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 10000, () => {
      setError(null)
      timer = 0
      return GLib.SOURCE_REMOVE
    })
  }

  const run = async (label: string, fn: () => Promise<unknown>) => {
    if (busy.get()) return
    setError(null)
    setBusy(label)
    try {
      await fn()
    } catch (e) {
      const msg = errorText(e)
      if (msg !== "Cancelled") showError(msg)
    } finally {
      setBusy(null)
    }
  }

  return { busy, error, run, showError }
}

const FORM_SECURITY: Partial<Record<Security, SecKind>> = {
  wep: "wep-key",
  enterprise: "wpa-eap",
  "enterprise-192": "wpa3-eap",
}

// A partial connection only when NM's auto-completion needs help: BSSID lock
// for router-default SSIDs, per-user permission without system rights.
function partialFor(net: WifiNet): NM.Connection | null {
  const lock = net.mode !== AP_MODE_ADHOC && isManufacturerDefault(net.ssid)
  const userOnly = !canModifySystem()
  if (!lock && !userOnly) return null
  const c = NM.SimpleConnection.new()
  const sCon = new NM.SettingConnection()
  if (userOnly) sCon.add_permission("user", GLib.get_user_name(), null)
  c.add_setting(sCon)
  if (lock) {
    const sWifi = new NM.SettingWireless({ ssid: ssidBytes(net.ssid) })
    sWifi.bssid = net.best.get_bssid()
    c.add_setting(sWifi)
  }
  return c
}

export function NetRow({ net, expanded, active }: { net: WifiNet; expanded: Expanded; active: boolean }) {
  const [open, setOpen] = expanded
  const isOpen = open((k) => k === net.key)
  const toggleOpen = () => setOpen(open.get() === net.key ? null : net.key)
  const dev = net.device
  const devState = createBinding(dev, "state")
  const connectivity = createBinding(client, "connectivity")
  const ops = createRowOps()

  const connect = (conn?: NM.RemoteConnection) => {
    if (!conn && net.connections.length > 1) return setOpen(net.key) // pick one in the panel
    const saved = conn ?? net.connections[0]
    if (saved) {
      return ops.run("Connecting…", () =>
        connectAndWait({ conn: saved, device: dev, specific: net.best.get_path() }))
    }
    const formSec = FORM_SECURITY[net.security]
    if (needsForm(net.security) && formSec) {
      setJoinRequest({
        kind: "wifi", device: dev, ap: net.best, lockSsid: true,
        form: { ssid: net.ssid, security: formSec },
      })
      return
    }
    // New open / WPA / WPA3 / OWE network: NM fills in the rest and asks our
    // secret agent for the password.
    return ops.run("Connecting…", () =>
      connectAndWait({ partial: partialFor(net), device: dev, specific: net.best.get_path() }))
  }

  const status = createComputed(() => {
    net.rev()
    const b = ops.busy()
    if (active) {
      const st = devState()
      const s = deviceStateText(st)
      if (s) return s
    } else if (b) return b
    const e = ops.error()
    if (e) return e
    const sec = SECURITY_LABEL[net.security]
    if (active) {
      const c = connectivityText(connectivity())
      return c ? `Connected · ${c}` : "Connected"
    }
    return net.saved ? `Saved · ${sec}` : sec
  })

  const icon = net.rev(() => strengthIcon(net.strength))
  const working = createComputed(() => !!ops.busy() || (active && deviceStateText(devState()) !== null))
  const rowClass = createComputed(() =>
    ["net-row", "bt-row", active && "active", ops.error() && "error", isOpen() && "open"].filter(Boolean).join(" "),
  )

  return (
    <box class="bt-device" orientation={Gtk.Orientation.VERTICAL}>
      <box class={rowClass}>
        <button class="bt-row-main" hexpand onClicked={() => (active ? toggleOpen() : connect())}>
          <box spacing={10}>
            <image iconName={icon} pixelSize={17} />
            <box orientation={Gtk.Orientation.VERTICAL} hexpand valign={Gtk.Align.CENTER}>
              <label class="bt-name" label={net.ssid} halign={Gtk.Align.START} ellipsize={3} maxWidthChars={24} />
              <label class={ops.error((e) => `bt-status${e ? " error" : ""}`)} label={status}
                halign={Gtk.Align.START} ellipsize={3} maxWidthChars={34} />
            </box>
            <Gtk.Spinner visible={working} $={(self) => self.connect("map", () => self.start())} />
            {isSecured(net.security) && (
              <image class="net-lock" iconName="network-wireless-encrypted-symbolic" pixelSize={13} />
            )}
            {active && <image class="net-check" iconName="object-select-symbolic" pixelSize={14} />}
          </box>
        </button>
        <button class="bt-expand" valign={Gtk.Align.CENTER} tooltipText="Details" onClicked={toggleOpen}>
          <image iconName={isOpen((o) => (o ? "pan-up-symbolic" : "pan-down-symbolic"))} pixelSize={14} />
        </button>
      </box>

      <revealer revealChild={isOpen} transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN} transitionDuration={180}>
        <With value={isOpen}>
          {(o) => (o ? <NetPanel net={net} active={active} ops={ops} connect={connect} /> : <box />)}
        </With>
      </revealer>
    </box>
  )
}

function NetPanel({ net, active, ops, connect }: {
  net: WifiNet
  active: boolean
  ops: ReturnType<typeof createRowOps>
  connect: (c?: NM.RemoteConnection) => unknown
}) {
  const dev = net.device
  const ac = createBinding(dev, "activeConnection")
  const [confirmForget, setConfirmForget] = createState(false)
  const details = net.rev(() => {
    const ap = net.best
    const f = ap.get_frequency()
    const rows: [string, string][] = [
      ["Security", SECURITY_LABEL[net.security]],
      ["Signal", `${ap.get_strength()}% · ${band(f)}${channel(f) ? ` · ch ${channel(f)}` : ""}`],
      ["BSSID", net.aps.length > 1 ? `${ap.get_bssid()} (+${net.aps.length - 1})` : (ap.get_bssid() ?? "")],
      ["Max rate", `${Math.round(ap.get_max_bitrate() / 1000)} Mb/s`],
    ]
    if (net.mode === AP_MODE_ADHOC) rows.push(["Mode", "Ad-hoc"])
    return rows
  })
  const conns = net.rev(() => [...net.connections])

  const forget = () => {
    if (!confirmForget.get()) {
      setConfirmForget(true)
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, 4000, () => (setConfirmForget(false), GLib.SOURCE_REMOVE))
      return
    }
    setConfirmForget(false)
    void ops.run("Forgetting…", () => Promise.all(net.connections.map(deleteConnection)))
  }

  return (
    <box class="bt-panel" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      {active ? (
        <With value={ac}>{(a) => (a ? <InfoPanel ac={a} /> : <box />)}</With>
      ) : (
        <box class="bt-info" orientation={Gtk.Orientation.VERTICAL} spacing={3}>
          <For each={details}>
            {([k, v]: [string, string]) => (
              <box spacing={12}>
                <label class="bt-info-key" label={k} widthChars={9} xalign={0} />
                <label class="bt-info-val" label={v} selectable xalign={0} hexpand />
              </box>
            )}
          </For>
        </box>
      )}

      <box orientation={Gtk.Orientation.VERTICAL} spacing={4} visible={conns((c) => c.length > 1)}>
        <label class="net-section-title" label="Connect Using" halign={Gtk.Align.START} />
        <For each={conns}>
          {(c: NM.RemoteConnection) => (
            <button class="bt-option" onClicked={() => void connect(c)}>
              <box spacing={8}>
                <label label={c.get_id()} hexpand halign={Gtk.Align.START} ellipsize={3} />
                <image class="net-check" iconName="object-select-symbolic" pixelSize={12}
                  visible={ac((a) => a?.get_uuid() === c.get_uuid())} />
              </box>
            </button>
          )}
        </For>
      </box>

      <box class="bt-actions" spacing={6} homogeneous>
        {active ? (
          <button class="bt-action" onClicked={() => void ops.run("Disconnecting…", () => disconnectDevice(dev))}>
            <label label="Disconnect" />
          </button>
        ) : (
          <button class="bt-action" onClicked={() => void connect()}>
            <label label="Connect" />
          </button>
        )}
        <button class="bt-action" visible={conns((c) => c.length > 0)}
          onClicked={() => {
            const uuid = (active ? ac.get()?.get_uuid() : null) ?? net.connections[0]?.get_uuid()
            if (uuid) openEditor(["--edit", uuid])
          }}>
          <label label="Edit…" />
        </button>
        <button class={confirmForget((c) => `bt-action destructive${c ? " confirm" : ""}`)}
          visible={conns((c) => c.length > 0)} onClicked={forget}>
          <label label={confirmForget((c) => (c ? "Really forget?" : "Forget"))} />
        </button>
      </box>
    </box>
  )
}
