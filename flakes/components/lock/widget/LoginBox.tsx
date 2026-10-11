import { Gdk, Gtk } from "ags/gtk4"
import { createComputed, createState, onCleanup } from "ags"
import GLib from "gi://GLib"
import AstalAuth from "gi://AstalAuth"
import { PAM_SERVICE } from "../config"

const USER = GLib.get_user_name()

// Bare password field bottom-right: user name, dots over a thin underline,
// arrow to submit, one status line (authenticating / error / caps lock).
// onSuccess fires only after PAM accepts the password.
export default function LoginBox({ onSuccess }: { onSuccess: () => void }) {
  const [busy, setBusy] = createState(false)
  const [error, setError] = createState<string | null>(null)
  const [capsLock, setCapsLock] = createState(false)
  let entry: Gtk.Entry | null = null
  let field: Gtk.Box | null = null

  // caps lock state from the seat keyboard
  const kb = Gdk.Display.get_default()?.get_default_seat()?.get_keyboard() ?? null
  if (kb) {
    setCapsLock(kb.capsLockState)
    const id = kb.connect("notify::caps-lock-state", () => setCapsLock(kb.capsLockState))
    onCleanup(() => kb.disconnect(id))
  }

  const fail = (msg: string) => {
    setBusy(false)
    setError(msg || "Authentication failed")
    if (entry) {
      entry.text = ""
      entry.grab_focus()
    }
    // retrigger the shake animation
    field?.remove_css_class("shake")
    field?.add_css_class("shake")
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 450, () => (field?.remove_css_class("shake"), GLib.SOURCE_REMOVE))
  }

  const submit = () => {
    const password = entry?.text ?? ""
    if (busy.get() || !password) return
    setBusy(true)
    setError(null)

    // fresh conversation per attempt
    const pam = new AstalAuth.Pam()
    pam.set_service(PAM_SERVICE)
    pam.connect("auth-prompt-hidden", () => pam.supply_secret(password))
    pam.connect("auth-prompt-visible", () => pam.supply_secret(password))
    // info/error messages (security key touch, faillock countdown, ...) are
    // shown; PAM then expects a NULL reply to carry on
    const message = (_p: AstalAuth.Pam, msg: string) => (msg && setError(msg), pam.supply_secret(null))
    pam.connect("auth-info", message)
    pam.connect("auth-error", message)
    pam.connect("success", () => onSuccess())
    pam.connect("fail", (_p: AstalAuth.Pam, msg: string) => fail(msg))
    if (!pam.start_authenticate()) fail("Could not start authentication")
  }

  const status = createComputed(() => {
    if (busy()) return "AUTHENTICATING…"
    const e = error()
    if (e) return e.toUpperCase()
    return capsLock() ? "CAPS LOCK IS ON" : ""
  })

  return (
    <box class="login" orientation={Gtk.Orientation.VERTICAL} halign={Gtk.Align.END} valign={Gtk.Align.END}
      spacing={8}>
      <label class="login-user" label={USER.toUpperCase()} halign={Gtk.Align.END} />
      <box class="login-field" spacing={8} $={(self) => (field = self)}>
        <Gtk.Entry
          class="login-entry"
          hexpand
          visibility={false}
          placeholderText="PASSWORD"
          sensitive={busy((b) => !b)}
          $={(self) => {
            entry = self
            self.set_invisible_char("●") // Orbitron's own bullet is tiny
            self.connect("activate", submit)
            self.connect("changed", () => error.get() && setError(null))
            self.connect("map", () => self.grab_focus())
            const keys = new Gtk.EventControllerKey()
            keys.connect("key-pressed", (_c, keyval) => {
              if (keyval !== Gdk.KEY_Escape) return false
              self.text = ""
              return true
            })
            self.add_controller(keys)
          }}
        />
        <button class="login-go" valign={Gtk.Align.CENTER} sensitive={busy((b) => !b)} onClicked={submit}>
          <label label="→" />
        </button>
      </box>
      <label
        class={error((e) => `login-status${e ? " error" : ""}`)}
        label={status}
        halign={Gtk.Align.END}
        opacity={status((s) => (s ? 1 : 0))}
      />
    </box>
  )
}
