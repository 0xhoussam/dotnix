import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import { createState, With, type Accessor } from "ags"
import NM from "gi://NM"
import {
  FAST_PROVISIONING, INNER, PEAP_VERSIONS, SEC_OPTIONS, STORAGE_OPTIONS, connectAndWait,
  defaultHotspot, eapOptionsFor, emptyWifiForm, hotspotCapable, isEap, joinRequest, savedWifiConnections,
  setJoinRequest, startHotspot, submitWifiForm, validateHotspot, validateWifiForm,
  type EapMethod, type HotspotForm, type JoinRequest, type SecKind, type WifiForm,
} from "./connections"
import { client, deviceName, errorText, notify } from "./util"

// Overlay forms nm-applet opens as dialogs: "Connect to Hidden Wi-Fi
// Network…", the 802.1X / WEP setup for a visible network ("Dialog of Doom"),
// and "Create New Wi-Fi Network…" (hotspot).

const [picking, setPicking] = createState(false) // a file chooser is open

// A mapped GTK4 window doesn't grow to a larger natural size on its own;
// drop the remembered size after the form changes shape.
let dialogWindow: Gtk.Window | null = null
const relayout = () => {
  dialogWindow?.set_default_size(-1, -1)
  dialogWindow?.queue_resize()
}

// ---- small form widgets -------------------------------------------------------------

function Select<T>({ options, value, onChange }: { options: [T, string][]; value: T; onChange: (v: T) => void }) {
  return (
    <Gtk.DropDown
      class="net-select"
      hexpand
      $={(self) => {
        self.model = Gtk.StringList.new(options.map((o) => o[1]))
        self.selected = Math.max(0, options.findIndex((o) => o[0] === value))
        self.connect("notify::selected", () => {
          const o = options[self.selected]
          if (o) onChange(o[0])
        })
      }}
    />
  )
}

function Row({ label, children }: { label: string; children: any }) {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
      <label class="net-field-label" label={label} halign={Gtk.Align.START} />
      {children}
    </box>
  )
}

type StrKeys<T> = { [K in keyof T]: T[K] extends string ? K : never }[keyof T]

function Text<T>({ form, k, password = false, placeholder = "", focus = false }: {
  form: T
  k: StrKeys<T>
  password?: boolean
  placeholder?: string
  focus?: boolean
}) {
  const setup = (self: Gtk.Editable) => {
    self.text = (form[k] as string) ?? ""
    self.connect("changed", () => ((form as any)[k] = self.text))
    if (focus) self.connect("map", () => self.grab_focus())
  }
  return password ? (
    <Gtk.PasswordEntry class="bt-entry net-entry" showPeekIcon placeholderText={placeholder} $={setup} />
  ) : (
    <Gtk.Entry class="bt-entry net-entry" placeholderText={placeholder} $={setup} />
  )
}

function FileField<T>({ form, k, title }: { form: T; k: StrKeys<T>; title: string }) {
  let entry: Gtk.Entry | null = null
  const choose = () => {
    const dialog = new Gtk.FileDialog({ title, modal: true })
    setPicking(true)
    dialog.open(null, null, (_d, res) => {
      setPicking(false)
      try {
        const path = dialog.open_finish(res)?.get_path()
        if (path && entry) entry.text = path
      } catch {
        // dismissed
      }
    })
  }
  return (
    <box spacing={6}>
      <Gtk.Entry class="bt-entry net-entry" hexpand placeholderText="(none)"
        $={(self) => {
          entry = self
          self.text = (form[k] as string) ?? ""
          self.connect("changed", () => ((form as any)[k] = self.text))
        }} />
      <button class="bt-chip" onClicked={choose} tooltipText="Choose file…">
        <image iconName="document-open-symbolic" pixelSize={14} />
      </button>
    </box>
  )
}

function Check<T>({ form, k, label, onToggle }: { form: T; k: keyof T; label: string; onToggle?: (v: boolean) => void }) {
  return (
    <Gtk.CheckButton class="net-check-btn" label={label} active={!!form[k]}
      $={(self) => self.connect("toggled", () => {
        ;(form as any)[k] = self.active
        onToggle?.(self.active)
      })} />
  )
}

// ---- 802.1X -------------------------------------------------------------------------

function EapFields({ form, sec }: { form: WifiForm; sec: SecKind }) {
  const options = eapOptionsFor(sec)
  if (!options.some(([m]) => m === form.eap)) form.eap = options[0][0]
  const [method, setMethod] = createState<EapMethod>(form.eap)
  const [noCa, setNoCa] = createState(form.noCa)

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
      <Row label="Authentication">
        <Select options={options} value={form.eap}
          onChange={(m) => ((form.eap = m), (form.inner = 0), setMethod(m), relayout())} />
      </Row>
      <With value={method}>
        {(m: EapMethod) => {
          const tunnel = m === "peap" || m === "ttls" || m === "fast"
          const usesCa = m === "tls" || m === "peap" || m === "ttls"
          const inner = INNER[m]
          return (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
              {tunnel && <Row label="Anonymous identity"><Text form={form} k="anonIdentity" /></Row>}
              {usesCa && <Row label="Domain"><Text form={form} k="domain" placeholder="e.g. radius.example.com" /></Row>}
              {usesCa && (
                <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
                  <Check form={form} k="noCa" label="No CA certificate is required" onToggle={(v) => (setNoCa(v), relayout())} />
                  <box orientation={Gtk.Orientation.VERTICAL} visible={noCa((n) => !n)}>
                    <Row label="CA certificate"><FileField form={form} k="caCert" title="Choose CA certificate" /></Row>
                  </box>
                </box>
              )}
              {m === "peap" && (
                <Row label="PEAP version">
                  <Select options={PEAP_VERSIONS} value={form.peapVersion} onChange={(v) => (form.peapVersion = v)} />
                </Row>
              )}
              {m === "fast" && (
                <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                  <Row label="PAC provisioning">
                    <Select options={FAST_PROVISIONING} value={form.fastProvisioning}
                      onChange={(v) => (form.fastProvisioning = v)} />
                  </Row>
                  <Row label="PAC file"><FileField form={form} k="pacFile" title="Choose PAC file" /></Row>
                </box>
              )}
              {inner && (
                <Row label="Inner authentication">
                  <Select options={inner.map(([label], i) => [i, label] as [number, string])} value={form.inner}
                    onChange={(i) => (form.inner = i)} />
                </Row>
              )}
              {m === "tls" ? (
                <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                  <Row label="Identity"><Text form={form} k="username" /></Row>
                  <Row label="User certificate"><FileField form={form} k="clientCert" title="Choose user certificate" /></Row>
                  <Row label="Private key"><FileField form={form} k="privateKey" title="Choose private key" /></Row>
                  <Row label="Private key password"><Text form={form} k="keyPassword" password /></Row>
                </box>
              ) : (
                <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                  <Row label="Username"><Text form={form} k="username" /></Row>
                  <Row label="Password"><Text form={form} k="password" password /></Row>
                </box>
              )}
            </box>
          )
        }}
      </With>
    </box>
  )
}

// ---- Wi-Fi form -----------------------------------------------------------------------

function SecurityFields({ form, sec }: { form: WifiForm; sec: SecKind }) {
  const storage = (
    <Row label="Password storage">
      <Select options={STORAGE_OPTIONS} value={form.storage} onChange={(s) => (form.storage = s)} />
    </Row>
  )
  switch (sec) {
    case "none":
    case "owe":
      return <box visible={false} />
    case "wpa-psk":
    case "sae":
      return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <Row label="Password"><Text form={form} k="password" password focus /></Row>
          {storage}
        </box>
      )
    case "wep-key":
    case "wep-pass":
      return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <Row label={sec === "wep-key" ? "Key" : "Passphrase"}><Text form={form} k="wepKey" password focus /></Row>
          <box spacing={8} homogeneous>
            <Row label="WEP index">
              <Select options={[0, 1, 2, 3].map((i) => [i, `${i + 1}${i === 0 ? " (Default)" : ""}`] as [number, string])}
                value={form.wepIndex} onChange={(i) => (form.wepIndex = i)} />
            </Row>
            <Row label="Authentication">
              <Select options={[["open", "Open System"], ["shared", "Shared Key"]] as ["open" | "shared", string][]}
                value={form.wepAuth} onChange={(a) => (form.wepAuth = a)} />
            </Row>
          </box>
          {storage}
        </box>
      )
    case "leap":
      return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <Row label="Username"><Text form={form} k="username" focus /></Row>
          <Row label="Password"><Text form={form} k="password" password /></Row>
          {storage}
        </box>
      )
    default:
      return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <EapFields form={form} sec={sec} />
          {storage}
        </box>
      )
  }
}

const wifiDevices = () => client.get_devices().filter((d) => d instanceof NM.DeviceWifi) as NM.DeviceWifi[]

function DevicePicker({ devices, value, onChange }: {
  devices: NM.DeviceWifi[]
  value: NM.DeviceWifi | null
  onChange: (d: NM.DeviceWifi) => void
}) {
  if (devices.length < 2) return <box visible={false} />
  return (
    <Row label="Wi-Fi adapter">
      <Select options={devices.map((d) => [d, deviceName(d)] as [NM.DeviceWifi, string])} value={value ?? devices[0]}
        onChange={onChange} />
    </Row>
  )
}

// Close right away and report failures as notifications: activation can
// trigger our own secrets prompt, which shouldn't fight this window for focus.
function runInBackground(label: string, job: () => Promise<void>) {
  setJoinRequest(null)
  job().catch((e) => {
    const msg = errorText(e)
    if (msg !== "Cancelled") void notify("Connection Failed", `${label}: ${msg}`, "network-error-symbolic")
  })
}

function WifiFormView({ req }: { req: Extract<JoinRequest, { kind: "wifi" }> }) {
  const form: WifiForm = { ...emptyWifiForm(), hidden: !req.lockSsid, ...req.form }
  let device = req.device ?? wifiDevices()[0] ?? null
  const [sec, setSec] = createState<SecKind>(form.security)
  const [error, setError] = createState<string | null>(null)

  // Hidden network: optionally reuse a saved Wi-Fi connection instead.
  const saved = req.lockSsid ? [] : savedWifiConnections()
  const [existing, setExisting] = createState<NM.RemoteConnection | null>(null)

  // A visible AP only offers the security types that can match it.
  const secOptions = !req.lockSsid
    ? SEC_OPTIONS
    : SEC_OPTIONS.filter(([s]) =>
        form.security === "wep-key" ? ["wep-key", "wep-pass", "leap", "dynamic-wep"].includes(s) : s === form.security)

  const submit = () => {
    const conn = existing.get()
    if (conn) {
      runInBackground(conn.get_id(), () => connectAndWait({ conn, device, removeOnFailure: false }))
      return
    }
    const err = validateWifiForm(form)
    if (err) return setError(err)
    if (!device) return setError("No Wi-Fi adapter available")
    const dev = device
    runInBackground(form.ssid, () => submitWifiForm(form, dev, req.ap))
  }

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      <Fields>
        <DevicePicker devices={wifiDevices()} value={device} onChange={(d) => (device = d)} />
        {saved.length > 0 && (
          <Row label="Connection">
            <Select
              options={[[null, "New…"] as [NM.RemoteConnection | null, string],
                ...saved.map((c) => [c, c.get_id()] as [NM.RemoteConnection | null, string])]}
              value={null}
              onChange={(c) => (setExisting(c), relayout())}
            />
          </Row>
        )}
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10} visible={existing((e) => e === null)}>
          {!req.lockSsid && <Row label="Network name"><Text form={form} k="ssid" focus /></Row>}
          <Row label="Security">
            <Select options={secOptions} value={form.security}
              onChange={(s) => ((form.security = s), setSec(s), relayout())} />
          </Row>
          <With value={sec}>{(s: SecKind) => <SecurityFields form={form} sec={s} />}</With>
        </box>
      </Fields>
      <FormFooter error={error} action="Connect" onSubmit={submit} />
    </box>
  )
}

// ---- hotspot ---------------------------------------------------------------------------

function HotspotFormView({ req }: { req: Extract<JoinRequest, { kind: "hotspot" }> }) {
  const form: HotspotForm = defaultHotspot()
  const devices = wifiDevices()
  let device = req.device
  const [sec, setSec] = createState(form.security)
  const [error, setError] = createState<string | null>(null)
  const ap = hotspotCapable(device)

  const submit = () => {
    const err = validateHotspot(form)
    if (err) return setError(err)
    const dev = device
    runInBackground("Hotspot", () => startHotspot(form, dev))
  }

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      <Fields>
        <DevicePicker devices={devices} value={device} onChange={(d) => (device = d)} />
        {!ap && (
          <label class="net-dialog-note" wrap xalign={0}
            label="This adapter can't run an access point; an open ad-hoc network will be created instead." />
        )}
        <Row label="Network name"><Text form={form} k="ssid" focus /></Row>
        {ap && (
          <Row label="Security">
            <Select
              options={[["wpa-psk", "WPA2 Personal"], ["sae", "WPA3 Personal"], ["none", "None"]] as [HotspotForm["security"], string][]}
              value={form.security}
              onChange={(s) => ((form.security = s), setSec(s), relayout())}
            />
          </Row>
        )}
        <box orientation={Gtk.Orientation.VERTICAL} visible={sec((s) => ap && s !== "none")}>
          <Row label="Password"><Text form={form} k="password" /></Row>
        </box>
        <Row label="Band">
          <Select options={[["", "Automatic"], ["bg", "2.4 GHz"], ["a", "5 GHz"]] as [HotspotForm["band"], string][]}
            value={form.band} onChange={(b) => (form.band = b)} />
        </Row>
        <label class="net-dialog-note" wrap xalign={0}
          label="Starting a hotspot disconnects this adapter from its current Wi-Fi network." />
      </Fields>
      <FormFooter error={error} action="Start" onSubmit={submit} />
    </box>
  )
}

// Scrollable field area; the footer with the action buttons stays put.
function Fields({ children }: { children: any }) {
  return (
    <Gtk.ScrolledWindow propagateNaturalHeight maxContentHeight={640} hscrollbarPolicy={Gtk.PolicyType.NEVER}>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>{children}</box>
    </Gtk.ScrolledWindow>
  )
}

function FormFooter({ error, action, onSubmit }: { error: Accessor<string | null>; action: string; onSubmit: () => void }) {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      <label class="net-dialog-error" label={error((e) => e ?? "")} visible={error((e) => !!e)} wrap xalign={0} />
      <box class="bt-dialog-actions" spacing={8} homogeneous>
        <button class="bt-dialog-btn" hexpand onClicked={() => setJoinRequest(null)}>
          <label label="Cancel" />
        </button>
        <button class="bt-dialog-btn suggested" hexpand onClicked={onSubmit}>
          <label label={action} />
        </button>
      </box>
    </box>
  )
}

function Body({ req }: { req: JoinRequest }) {
  const title =
    req.kind === "hotspot"
      ? "Create Wi-Fi Hotspot"
      : req.lockSsid
        ? `Connect to “${req.form.ssid}”`
        : "Connect to Hidden Wi-Fi Network"
  const message =
    req.kind === "hotspot"
      ? "Share this computer's connection over Wi-Fi."
      : req.lockSsid
        ? "This network needs more information before connecting."
        : "Enter the name and security details of the hidden network."
  return (
    <box class="bt-dialog net-dialog" orientation={Gtk.Orientation.VERTICAL} spacing={14} widthRequest={400}>
      <box spacing={12}>
        <image class="bt-dialog-icon"
          iconName={req.kind === "hotspot" ? "network-wireless-hotspot-symbolic" : "network-wireless-symbolic"}
          pixelSize={32} />
        <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER} hexpand>
          <label class="bt-dialog-title" label={title} halign={Gtk.Align.START} ellipsize={3} maxWidthChars={34} />
          <label class="bt-dialog-sub" label={message} halign={Gtk.Align.START} wrap xalign={0} />
        </box>
      </box>
      {req.kind === "hotspot" ? <HotspotFormView req={req} /> : <WifiFormView req={req} />}
    </box>
  )
}

export default function JoinDialog(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name="net-join"
      namespace="net-join"
      class="BtPairing NetDialog"
      gdkmonitor={gdkmonitor}
      visible={joinRequest((r) => r !== null)}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={picking((p) => (p ? Astal.Keymode.NONE : Astal.Keymode.EXCLUSIVE))}
      application={app}
      $={(self) => {
        dialogWindow = self
        joinRequest.subscribe(relayout)
        const keys = new Gtk.EventControllerKey()
        keys.connect("key-pressed", (_c, keyval) => {
          if (keyval === Gdk.KEY_Escape && joinRequest.get()) {
            setJoinRequest(null)
            return true
          }
          return false
        })
        self.add_controller(keys)
        // keep the file chooser above us while it's open
        picking.subscribe(() => (self.layer = picking.get() ? Astal.Layer.BOTTOM : Astal.Layer.OVERLAY))
      }}
    >
      <With value={joinRequest}>{(r) => (r ? <Body req={r} /> : <box />)}</With>
    </window>
  )
}

