/** @jsxImportSource ags/gtk3 */
import Gtk from "gi://Gtk?version=3.0"
import GLib from "gi://GLib?version=2.0"
import AstalAuth from "gi://AstalAuth?version=0.1"
import { createState } from "ags"

const HOME = GLib.get_home_dir()
const FACE = `${HOME}/.face`
const NAME = (() => {
  const real = GLib.get_real_name()
  return !real || real === "Unknown" ? GLib.get_user_name() : real
})()

const DEFAULT_HINT = "Enter Password to unlock"

// PAM service to authenticate against. Must exist in /etc/pam.d.
// "swaylock" ships on most Wayland setups and is meant for unprivileged
// self-auth. For a dedicated service, add security.pam.services.<name> in
// NixOS and set it here.
const SERVICE = "swaylock"

function Avatar() {
  // Astal.Icon takes an icon name OR a file path in the `icon` prop.
  const icon = GLib.file_test(FACE, GLib.FileTest.EXISTS)
    ? FACE
    : "avatar-default-symbolic"
  return <icon class="avatar" icon={icon} pixelSize={64} />
}

// onSuccess fires only after PAM accepts the password.
export default function LoginBox(onSuccess: () => void) {
  const [hint, setHint] = createState(DEFAULT_HINT)
  const [error, setError] = createState(false)
  const [busy, setBusy] = createState(false)

  function fail(entry: Gtk.Entry, msg: string) {
    setBusy(false)
    setError(true)
    setHint(msg || "Authentication failed")
    entry.text = ""
    entry.grab_focus()

    // shake: add class, remove after the animation so it can retrigger
    const ctx = entry.get_style_context()
    ctx.add_class("shake")
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
      ctx.remove_class("shake")
      return GLib.SOURCE_REMOVE
    })
  }

  function authenticate(entry: Gtk.Entry) {
    const password = entry.text
    if (busy.get() || password === "") return

    setBusy(true)
    setError(false)
    setHint("Authenticating…")

    // Fresh Pam per attempt; start_authenticate runs one conversation.
    const pam = new AstalAuth.Pam()
    pam.set_service(SERVICE)
    pam.connect("auth-prompt-hidden", () => pam.supply_secret(password))
    pam.connect("auth-prompt-visible", () => pam.supply_secret(password))
    pam.connect("success", () => onSuccess())
    pam.connect("fail", (_p: AstalAuth.Pam, msg: string) => fail(entry, msg))

    if (!pam.start_authenticate()) {
      fail(entry, "Could not start authentication")
    }
  }

  return (
    <box
      class="login"
      vertical
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
    >
      <Avatar />
      <label class="login-name" label={NAME} />
      <entry
        class="login-entry"
        visibility={false}
        placeholderText="Enter Password"
        xalign={0.5}
        sensitive={busy.as((b) => !b)}
        onActivate={(self) => authenticate(self)}
      />
      <label
        class={error.as((e) => (e ? "login-hint error" : "login-hint"))}
        label={hint}
      />
    </box>
  )
}
