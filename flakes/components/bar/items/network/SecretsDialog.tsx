import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import { createState, With } from "ags"
import { USER_CANCEL, answerSecrets, currentSecret, type SecretPrompt } from "./prompts"

// Centered overlay for the secret agent's prompts: Wi-Fi password / WEP key,
// 802.1X username + password, PPPoE / mobile / WireGuard / VPN fallbacks.

function Body({ id, prompt }: { id: number; prompt: SecretPrompt }) {
  const entries = new Map<string, Gtk.Editable>()
  const [error, setError] = createState<string | null>(null)

  const submit = () => {
    const out: Record<string, string> = {}
    for (const f of prompt.fields) {
      const v = entries.get(f.key)?.text ?? ""
      const err = f.validate?.(v)
      if (err) {
        setError(`${f.label}: ${err}`)
        entries.get(f.key)?.grab_focus()
        return
      }
      out[f.key] = v
    }
    answerSecrets(id, out)
  }

  return (
    <box class="bt-dialog net-dialog" orientation={Gtk.Orientation.VERTICAL} spacing={14} widthRequest={380}>
      <box spacing={12}>
        <image class="bt-dialog-icon" iconName={prompt.icon} pixelSize={32} />
        <label class="bt-dialog-title" label={prompt.title} halign={Gtk.Align.START} hexpand wrap xalign={0} />
      </box>

      <label class="bt-dialog-msg" label={prompt.message} wrap halign={Gtk.Align.START} xalign={0} />
      {prompt.note && <label class="net-dialog-note" label={prompt.note} wrap xalign={0} />}

      <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        {prompt.fields.map((f, i) => {
          const setup = (self: Gtk.Editable) => {
            entries.set(f.key, self)
            if (f.value) self.text = f.value
            self.connect("activate", submit)
            self.connect("changed", () => setError(null))
            if (i === 0) self.connect("map", () => self.grab_focus())
          }
          return (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
              <label class="net-field-label" label={f.label} halign={Gtk.Align.START} />
              {f.password ? (
                <Gtk.PasswordEntry class="bt-entry net-entry" showPeekIcon $={setup} />
              ) : (
                <Gtk.Entry class="bt-entry net-entry" $={setup} />
              )}
            </box>
          )
        })}
      </box>

      <label class="net-dialog-error" label={error((e) => e ?? "")} visible={error((e) => !!e)} wrap xalign={0} />

      <box class="bt-dialog-actions" spacing={8} homogeneous>
        <button class="bt-dialog-btn" hexpand onClicked={() => answerSecrets(id, USER_CANCEL)}>
          <label label="Cancel" />
        </button>
        <button class="bt-dialog-btn suggested" hexpand onClicked={submit}>
          <label label="Connect" />
        </button>
      </box>
    </box>
  )
}

export default function SecretsDialog(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name="net-secrets"
      namespace="net-secrets"
      class="BtPairing NetDialog"
      gdkmonitor={gdkmonitor}
      visible={currentSecret((c) => c !== null)}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.EXCLUSIVE}
      application={app}
      $={(self) => {
        const keys = new Gtk.EventControllerKey()
        keys.connect("key-pressed", (_c, keyval) => {
          const c = currentSecret.get()
          if (keyval === Gdk.KEY_Escape && c) {
            answerSecrets(c.id, USER_CANCEL)
            return true
          }
          return false
        })
        self.add_controller(keys)
      }}
    >
      <With value={currentSecret}>{(c) => (c ? <Body id={c.id} prompt={c.prompt} /> : <box />)}</With>
    </window>
  )
}
