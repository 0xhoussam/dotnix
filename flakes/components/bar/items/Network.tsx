import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createState, With, For } from "ags"
import { execAsync } from "ags/process"
import AstalNetwork from "gi://AstalNetwork"

const isSecured = (ap: AstalNetwork.AccessPoint) =>
  (ap.rsnFlags | ap.wpaFlags) !== 0

// Wi-Fi indicator + macOS-style popover: toggle, known network, other
// networks, connect (with inline password prompt when required).
export function Network() {
  const net = AstalNetwork.get_default()
  const wifi = net.wifi

  // Wired-only / no wifi device: just show a static icon.
  if (!wifi) {
    const wired = net.wired
    const icon = wired ? createBinding(wired, "iconName") : null
    return (
      <button class="network">
        <image iconName={icon ? icon((i) => i || "network-wired-symbolic") : "network-wired-symbolic"} pixelSize={16} />
      </button>
    )
  }

  const barIcon = createBinding(wifi, "iconName")
  const enabled = createBinding(wifi, "enabled")
  const aps = createBinding(wifi, "accessPoints")
  const active = createBinding(wifi, "activeAccessPoint")

  const [pwFor, setPwFor] = createState<string | null>(null)
  const [busy, setBusy] = createState<string | null>(null)
  let pwEntry: Gtk.Entry | null = null

  // Other networks: drop empty/active ssids, dedupe, strongest first.
  const others = createComputed(() => {
    const act = active()
    const seen = new Set<string>()
    return aps()
      .filter((ap) => ap.ssid && ap.ssid !== act?.ssid)
      .sort((a, b) => b.strength - a.strength)
      .filter((ap) => (seen.has(ap.ssid) ? false : (seen.add(ap.ssid), true)))
      .slice(0, 15)
  })

  const connect = (ssid: string, password?: string) => {
    setBusy(ssid)
    const cmd = password
      ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
      : ["nmcli", "device", "wifi", "connect", ssid]
    execAsync(cmd)
      .then(() => {
        setBusy(null)
        setPwFor(null)
      })
      .catch(() => {
        // failed -> almost always needs a password
        setBusy(null)
        setPwFor(ssid)
      })
  }

  const submitPassword = () => {
    const ssid = pwFor.get()
    const pw = pwEntry?.text ?? ""
    if (ssid && pw) connect(ssid, pw)
  }

  return (
    <menubutton class="network">
      <image iconName={barIcon((i) => i || "network-wireless-symbolic")} pixelSize={16} />
      <popover
        class="net-popover"
        $={(self) =>
          self.connect("notify::visible", () => {
            if (self.visible) {
              setPwFor(null)
              wifi.scan()
            }
          })
        }
      >
        <box class="net-panel" orientation={Gtk.Orientation.VERTICAL}>
          <box class="net-header">
            <label label="Wi-Fi" hexpand halign={Gtk.Align.START} />
            <switch
              class="net-switch"
              active={enabled}
              $={(self) =>
                self.connect("notify::active", () => {
                  if (self.active !== wifi.enabled) wifi.set_enabled(self.active)
                })
              }
            />
          </box>

          <box
            class="net-body"
            orientation={Gtk.Orientation.VERTICAL}
            visible={enabled}
          >
            <With value={active}>
              {(ap: AstalNetwork.AccessPoint | null) =>
                ap ? (
                  <box class="net-section" orientation={Gtk.Orientation.VERTICAL}>
                    <label class="net-section-title" label="Known Network" halign={Gtk.Align.START} />
                    <NetRow ap={ap} busy={busy} active onClicked={() => {}} />
                  </box>
                ) : (
                  <box />
                )
              }
            </With>

            <label class="net-section-title" label="Other Networks" halign={Gtk.Align.START} />
            <Gtk.ScrolledWindow heightRequest={260} hscrollbarPolicy={Gtk.PolicyType.NEVER}>
              <box class="net-list" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
                <label
                  class="net-empty"
                  label="No networks found"
                  visible={others((l) => l.length === 0)}
                />
                <For each={others}>
                  {(ap: AstalNetwork.AccessPoint) => (
                    <NetRow ap={ap} busy={busy} onClicked={() => connect(ap.ssid)} />
                  )}
                </For>
              </box>
            </Gtk.ScrolledWindow>

            <box
              class="net-password"
              orientation={Gtk.Orientation.VERTICAL}
              spacing={6}
              visible={pwFor((p) => p !== null)}
            >
              <label
                class="net-password-label"
                label={pwFor((p) => `Password for ${p ?? ""}`)}
                halign={Gtk.Align.START}
              />
              <box spacing={6}>
                <entry
                  class="net-entry"
                  hexpand
                  visibility={false}
                  placeholderText="Password"
                  $={(self) => (pwEntry = self)}
                  onActivate={submitPassword}
                />
                <button class="net-connect" onClicked={submitPassword}>
                  <label label="Connect" />
                </button>
              </box>
            </box>
          </box>

          <button
            class="net-settings"
            onClicked={() => execAsync(["nm-connection-editor"]).catch(() => {})}
          >
            <label label="Network Settings…" halign={Gtk.Align.START} hexpand />
          </button>
        </box>
      </popover>
    </menubutton>
  )
}

function NetRow({
  ap,
  busy,
  active = false,
  onClicked,
}: {
  ap: AstalNetwork.AccessPoint
  busy: ReturnType<typeof createState<string | null>>[0]
  active?: boolean
  onClicked: () => void
}) {
  return (
    <button class={`net-row${active ? " active" : ""}`} onClicked={onClicked}>
      <box spacing={10}>
        <image iconName={ap.iconName || "network-wireless-symbolic"} pixelSize={17} />
        <label label={ap.ssid} hexpand halign={Gtk.Align.START} ellipsize={3} maxWidthChars={22} />
        {active && <image class="net-check" iconName="object-select-symbolic" pixelSize={14} />}
        <Gtk.Spinner
          visible={busy((b) => b === ap.ssid)}
          $={(self) => self.connect("map", () => self.start())}
        />
        {isSecured(ap) && (
          <image class="net-lock" iconName="network-wireless-encrypted-symbolic" pixelSize={13} />
        )}
      </box>
    </button>
  )
}
