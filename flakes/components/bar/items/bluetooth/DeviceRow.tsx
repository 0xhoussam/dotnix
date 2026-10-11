import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createState, For, With, onCleanup, type Accessor } from "ags"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth"
import AstalWp from "gi://AstalWp"
import { audio, micFor, profilesOf, speakerFor, wpDeviceFor } from "./audio"
import { pickAndSend } from "./obex"
import {
  batteryPct, cancelPairing, className, connectableProfiles, connectDevice, connectProfile, deviceIcon,
  disconnectDevice, disconnectProfile, errorText, isCancelled, pairTrustConnect, removeDevice,
  rssiText, serviceName, settings, toggleAutoConnect, uuid16,
} from "./util"

type Expanded = [Accessor<string | null>, (v: string | null) => void]

// One device: a clickable row (pair / connect / disconnect) plus an
// expandable panel mirroring blueman's device menu and info dialog.
export function DeviceRow({ device, expanded }: { device: AstalBluetooth.Device; expanded: Expanded }) {
  const [open, setOpen] = expanded
  const isOpen = open((a) => a === device.address)

  const connected = createBinding(device, "connected")
  const connecting = createBinding(device, "connecting")
  const paired = createBinding(device, "paired")
  const alias = createBinding(device, "alias")
  const battery = createBinding(device, "batteryPercentage")
  const blocked = createBinding(device, "blocked")

  // "Pairing…" / "Connecting…" while a request we made is in flight
  const [busy, setBusy] = createState<string | null>(null)
  const [error, setError] = createState<string | null>(null)
  let errorTimer = 0

  const showError = (e: unknown) => {
    if (isCancelled(e)) return
    setError(errorText(e))
    if (errorTimer) GLib.source_remove(errorTimer)
    errorTimer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 8000, () => {
      setError(null)
      errorTimer = 0
      return GLib.SOURCE_REMOVE
    })
  }
  onCleanup(() => errorTimer && GLib.source_remove(errorTimer))

  const run = async (label: string, fn: () => Promise<unknown>) => {
    if (busy.get()) return
    setError(null)
    setBusy(label)
    try {
      await fn()
    } catch (e) {
      showError(e)
    } finally {
      setBusy(null)
    }
  }

  const primary = () => {
    if (device.blocked) return showError("Device is blocked — unblock it in the details panel")
    if (device.connected) return run("Disconnecting…", () => disconnectDevice(device))
    if (device.paired) return run("Connecting…", () => connectDevice(device))
    return run("Pairing…", () => pairTrustConnect(device))
  }

  const status = createComputed(() => {
    const b = busy()
    if (b) return b
    const e = error()
    if (e) return e
    if (connecting()) return "Connecting…"
    if (blocked()) return "Blocked"
    if (connected()) {
      const pct = batteryPct(battery())
      return pct >= 0 ? `Connected · ${pct}%` : "Connected"
    }
    return paired() ? "Not connected" : "Not paired"
  })

  const rowClass = createComputed(() =>
    ["net-row", "bt-row", connected() && "active", error() && "error", isOpen() && "open"].filter(Boolean).join(" "),
  )

  return (
    <box class="bt-device" orientation={Gtk.Orientation.VERTICAL}>
      <box class={rowClass}>
        <button class="bt-row-main" hexpand onClicked={primary}>
          <box spacing={10}>
            <image iconName={deviceIcon(device)} pixelSize={18} />
            <box orientation={Gtk.Orientation.VERTICAL} hexpand valign={Gtk.Align.CENTER}>
              <label
                class="bt-name"
                label={alias((a) => a || device.name || device.address)}
                halign={Gtk.Align.START}
                ellipsize={3}
                maxWidthChars={22}
              />
              <label class={error((e) => `bt-status${e ? " error" : ""}`)} label={status} halign={Gtk.Align.START}
                ellipsize={3} maxWidthChars={30} />
            </box>
            <Gtk.Spinner
              visible={createComputed(() => !!busy() || connecting())}
              $={(self) => self.connect("map", () => self.start())}
            />
          </box>
        </button>
        <button
          class="bt-expand"
          valign={Gtk.Align.CENTER}
          tooltipText="Details"
          onClicked={() => setOpen(open.get() === device.address ? null : device.address)}
        >
          <image iconName={isOpen((o) => (o ? "pan-up-symbolic" : "pan-down-symbolic"))} pixelSize={14} />
        </button>
      </box>

      <revealer revealChild={isOpen} transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN} transitionDuration={180}>
        <With value={isOpen}>
          {(o) => (o ? <DevicePanel device={device} run={run} busy={busy} /> : <box />)}
        </With>
      </revealer>
    </box>
  )
}

function DevicePanel({ device, run, busy }: {
  device: AstalBluetooth.Device
  run: (label: string, fn: () => Promise<unknown>) => Promise<void>
  busy: Accessor<string | null>
}) {
  const paired = createBinding(device, "paired")
  const connected = createBinding(device, "connected")
  const trusted = createBinding(device, "trusted")
  const blocked = createBinding(device, "blocked")
  const rssi = createBinding(device, "rssi")
  const uuids = createBinding(device, "uuids")
  const battery = createBinding(device, "batteryPercentage")
  const autoConnect = settings((s) => s.autoConnect.includes(device.address))

  const profiles = uuids(() => connectableProfiles(device))
  const canSend = uuids((u) => (u ?? []).some((x) => uuid16(x) === 0x1105))

  const [confirmForget, setConfirmForget] = createState(false)

  return (
    <box class="bt-panel" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      {/* details */}
      <box class="bt-info" orientation={Gtk.Orientation.VERTICAL} spacing={3}>
        <InfoRow k="Address" v={device.address} />
        <InfoRow k="Type" v={className(device.class)} />
        <InfoRow k="Signal" v={rssi((r) => rssiText(r))} />
        <InfoRow k="Battery" v={battery((b) => (batteryPct(b) >= 0 ? `${batteryPct(b)}%` : "—"))} />
      </box>

      {/* rename */}
      <Gtk.Entry
        class="bt-entry bt-rename"
        placeholderText="Rename device"
        primaryIconName="document-edit-symbolic"
        tooltipText="Rename (Enter to save, empty to reset)"
        text={device.alias}
        $={(self) =>
          self.connect("activate", () => {
            const name = self.text.trim()
            device.alias = name // empty resets to the device's own name
            self.text = device.alias
          })
        }
      />

      {/* toggles */}
      <box class="bt-toggles" orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        <ToggleRow label="Trusted" hint="Connect without asking" active={trusted}
          onToggle={(v) => (device.trusted = v)} />
        <ToggleRow label="Auto-connect" hint="Reconnect when Bluetooth turns on" active={autoConnect}
          visible={paired} onToggle={(v) => toggleAutoConnect(device.address, v)} />
        <ToggleRow label="Blocked" hint="Refuse all connections" active={blocked}
          onToggle={(v) => (device.blocked = v)} />
      </box>

      {/* per-profile connect */}
      <box orientation={Gtk.Orientation.VERTICAL} spacing={4} visible={createComputed(() => paired() && profiles().length > 0)}>
        <label class="net-section-title" label="Services" halign={Gtk.Align.START} />
        <For each={profiles}>
          {(uuid: string) => (
            <box class="bt-profile" spacing={6}>
              <label label={serviceName(uuid)} hexpand halign={Gtk.Align.START} />
              <button class="bt-chip" tooltipText="Connect this service"
                onClicked={() => run("Connecting…", () => connectProfile(device, uuid))}>
                <image iconName="media-playback-start-symbolic" pixelSize={12} />
              </button>
              <button class="bt-chip" tooltipText="Disconnect this service"
                onClicked={() => run("Disconnecting…", () => disconnectProfile(device, uuid))}>
                <image iconName="media-playback-stop-symbolic" pixelSize={12} />
              </button>
            </box>
          )}
        </For>
      </box>

      {/* PipeWire audio profile + default device */}
      {audio && (
        <box orientation={Gtk.Orientation.VERTICAL}>
          <AudioSection device={device} connected={connected} />
        </box>
      )}

      {/* actions */}
      <box class="bt-actions" spacing={6} homogeneous>
        <button class="bt-action" visible={busy((b) => b === "Pairing…")}
          onClicked={() => void cancelPairing(device)}>
          <label label="Cancel" />
        </button>
        <button class="bt-action" visible={createComputed(() => connected() && canSend())}
          onClicked={() => pickAndSend(device)}>
          <label label="Send Files…" />
        </button>
        <button
          class={confirmForget((c) => `bt-action destructive${c ? " confirm" : ""}`)}
          visible={paired}
          onClicked={() => {
            if (!confirmForget.get()) {
              setConfirmForget(true)
              GLib.timeout_add(GLib.PRIORITY_DEFAULT, 4000, () => (setConfirmForget(false), GLib.SOURCE_REMOVE))
              return
            }
            setConfirmForget(false)
            void run("Removing…", () => removeDevice(device))
          }}
        >
          <label label={confirmForget((c) => (c ? "Really forget?" : "Forget"))} />
        </button>
      </box>
    </box>
  )
}

function InfoRow({ k, v }: { k: string; v: Accessor<string> | string }) {
  return (
    <box spacing={12}>
      <label class="bt-info-key" label={k} widthChars={8} xalign={0} />
      <label class="bt-info-val" label={v} selectable xalign={0} hexpand />
    </box>
  )
}

function ToggleRow({ label, hint, active, onToggle, visible = true }: {
  label: string
  hint: string
  active: Accessor<boolean>
  onToggle: (v: boolean) => void
  visible?: Accessor<boolean> | boolean
}) {
  return (
    <box class="bt-toggle" spacing={8} visible={visible}>
      <box orientation={Gtk.Orientation.VERTICAL} hexpand>
        <label label={label} halign={Gtk.Align.START} />
        <label class="bt-hint" label={hint} halign={Gtk.Align.START} />
      </box>
      <switch
        class="net-switch"
        valign={Gtk.Align.CENTER}
        active={active}
        $={(self) =>
          self.connect("notify::active", () => {
            if (self.active !== active.get()) onToggle(self.active)
          })
        }
      />
    </box>
  )
}

function AudioSection({ device, connected }: { device: AstalBluetooth.Device; connected: Accessor<boolean> }) {
  const devices = createBinding(audio!, "devices")
  const wpDev = createComputed(() => (devices(), connected() ? wpDeviceFor(device.address) : null))

  return (
    <With value={wpDev}>
      {(dev) => (dev ? <AudioControls dev={dev} /> : <box visible={false} />)}
    </With>
  )
}

function AudioControls({ dev }: { dev: AstalWp.Device }) {
  const profiles = createBinding(dev, "profiles")
  const activeId = createBinding(dev, "activeProfileId")
  const options = profiles(() => profilesOf(dev))

  const speakers = createBinding(audio!, "speakers")
  const mics = createBinding(audio!, "microphones")

  const speaker = createComputed(() => (speakers(), activeId(), speakerFor(dev)))
  const mic = createComputed(() => (mics(), activeId(), micFor(dev)))
  const speakerIsDefault = createComputed(() => {
    const s = speaker()
    return s ? createBinding(s, "isDefault")() : false
  })
  const micIsDefault = createComputed(() => {
    const m = mic()
    return m ? createBinding(m, "isDefault")() : false
  })

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
      <label class="net-section-title" label="Audio Profile" halign={Gtk.Align.START} />
      <For each={options}>
        {(p) => (
          <button
            class={activeId((id) => `bt-option${id === p.index ? " active" : ""}`)}
            onClicked={() => dev.set_active_profile_id(p.index)}
          >
            <box spacing={8}>
              <label label={p.label} hexpand halign={Gtk.Align.START} ellipsize={3} />
              <image class="net-check" iconName="object-select-symbolic" pixelSize={12}
                visible={activeId((id) => id === p.index)} />
            </box>
          </button>
        )}
      </For>
      <box spacing={6} homogeneous>
        <button
          class={speakerIsDefault((d) => `bt-action${d ? " on" : ""}`)}
          visible={speaker((s) => !!s)}
          sensitive={speakerIsDefault((d) => !d)}
          onClicked={() => speaker.get()?.set_is_default(true)}
        >
          <label label={speakerIsDefault((d) => (d ? "Default Output" : "Use as Output"))} />
        </button>
        <button
          class={micIsDefault((d) => `bt-action${d ? " on" : ""}`)}
          visible={mic((m) => !!m)}
          sensitive={micIsDefault((d) => !d)}
          onClicked={() => mic.get()?.set_is_default(true)}
        >
          <label label={micIsDefault((d) => (d ? "Default Mic" : "Use as Mic"))} />
        </button>
      </box>
    </box>
  )
}

