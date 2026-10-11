import app from "ags/gtk4/app"
import { Astal, Gdk, Gtk } from "ags/gtk4"
import { With, onCleanup } from "ags"
import { current, answer, cancelCurrent, type Prompt, type Answer } from "./prompts"
import { deviceByPath, displayName, deviceIcon, formatBytes, pathToAddress, serviceName } from "./util"

// Centered overlay that renders the pending agent prompt (pairing PIN /
// passkey / confirmation, service authorization, incoming file).

const fmtPasskey = (n: number) => {
  const s = n.toString().padStart(6, "0")
  return `${s.slice(0, 3)} ${s.slice(3)}`
}

const needsKeyboard = (p: Prompt | undefined) => p?.kind === "pin" || p?.kind === "passkey"

function title(p: Prompt): string {
  switch (p.kind) {
    case "pin":
    case "passkey":
    case "confirm":
    case "show-pin":
    case "show-passkey":
      return "Pairing Request"
    case "authorize":
      return "Allow Pairing?"
    case "service":
      return "Allow Connection?"
    case "file":
      return "Incoming File"
  }
}

function message(p: Prompt, name: string): string {
  switch (p.kind) {
    case "pin":
      return `Enter the PIN code for ${name}. Simple devices often use 0000 or 1234.`
    case "passkey":
      return `Enter the 6-digit passkey shown on ${name}.`
    case "confirm":
      return `Confirm that ${name} shows the same passkey.`
    case "show-pin":
      return `Type this PIN on ${name}, then press Enter on it.`
    case "show-passkey":
      return `Type this passkey on ${name}, then press Enter on it.`
    case "authorize":
      return `${name} wants to pair with this computer.`
    case "service":
      return `${name} wants to use ${serviceName(p.uuid)}.`
    case "file":
      return `${name} wants to send you a file.`
  }
}

function Body({ id, prompt }: { id: number; prompt: Prompt }) {
  const dev = deviceByPath(prompt.path)
  const name = displayName(dev, pathToAddress(prompt.path))
  const reply = (a: Answer) => answer(id, a)

  // Close display-only prompts once pairing completes.
  if (dev) {
    const h = dev.connect("notify::paired", () => dev.paired && cancelCurrent(prompt.path))
    onCleanup(() => dev.disconnect(h))
  }

  let entry: Gtk.Entry | null = null
  const submit = () => {
    const text = entry?.text.trim() ?? ""
    if (prompt.kind === "pin" && text) reply(text)
    if (prompt.kind === "passkey" && /^\d{1,6}$/.test(text)) reply(parseInt(text, 10))
  }

  const Btn = ({ label, cls = "", value, onClicked }: {
    label: string; cls?: string; value?: Answer; onClicked?: () => void
  }) => (
    <button class={`bt-dialog-btn ${cls}`} hexpand onClicked={onClicked ?? (() => reply(value!))}>
      <label label={label} />
    </button>
  )

  return (
    <box class="bt-dialog" orientation={Gtk.Orientation.VERTICAL} spacing={14} widthRequest={360}>
      <box spacing={12}>
        <image class="bt-dialog-icon" iconName={dev ? deviceIcon(dev) : "bluetooth-active-symbolic"} pixelSize={32} />
        <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER}>
          <label class="bt-dialog-title" label={title(prompt)} halign={Gtk.Align.START} />
          <label class="bt-dialog-sub" label={name} halign={Gtk.Align.START} ellipsize={3} maxWidthChars={30} />
        </box>
      </box>

      <label class="bt-dialog-msg" label={message(prompt, name)} wrap halign={Gtk.Align.START} xalign={0} />

      {prompt.kind === "confirm" && <label class="bt-passkey" label={fmtPasskey(prompt.passkey)} />}
      {prompt.kind === "show-pin" && <label class="bt-passkey" label={prompt.pin} selectable />}
      {prompt.kind === "show-passkey" && (
        <label
          class="bt-passkey"
          useMarkup
          label={(() => {
            // dim the digits the remote side has already typed
            const s = fmtPasskey(prompt.passkey)
            const n = prompt.entered + (prompt.entered > 3 ? 1 : 0)
            return `<span alpha="45%">${s.slice(0, n)}</span>${s.slice(n)}`
          })()}
        />
      )}
      {prompt.kind === "file" && (
        <box class="bt-file" spacing={10}>
          <image iconName="text-x-generic-symbolic" pixelSize={20} />
          <label label={prompt.name} hexpand halign={Gtk.Align.START} ellipsize={2} />
          <label class="bt-file-size" label={prompt.size ? formatBytes(prompt.size) : ""} />
        </box>
      )}

      {needsKeyboard(prompt) && (
        <Gtk.Entry
          class="bt-entry"
          placeholderText={prompt.kind === "pin" ? "PIN code" : "000000"}
          maxLength={prompt.kind === "pin" ? 16 : 6}
          inputPurpose={prompt.kind === "pin" ? Gtk.InputPurpose.FREE_FORM : Gtk.InputPurpose.DIGITS}
          $={(self) => {
            entry = self
            self.connect("activate", submit)
            self.connect("map", () => self.grab_focus())
          }}
        />
      )}

      <box class="bt-dialog-actions" spacing={8} homogeneous>
        {(() => {
          switch (prompt.kind) {
            case "pin":
            case "passkey":
              return [<Btn label="Cancel" value={null} />, <Btn label="Pair" cls="suggested" onClicked={submit} />]
            case "confirm":
              return [<Btn label="Cancel" value={null} />, <Btn label="Pair" cls="suggested" value={true} />]
            case "authorize":
              return [<Btn label="Reject" value={null} />, <Btn label="Allow" cls="suggested" value={true} />]
            case "service":
              return [
                <Btn label="Reject" value={null} />,
                <Btn label="Allow once" value={true} />,
                <Btn label="Always" cls="suggested" value="always" />,
              ]
            case "file":
              return [<Btn label="Decline" value={null} />, <Btn label="Accept" cls="suggested" value={true} />]
            case "show-pin":
            case "show-passkey":
              return [<Btn label="Cancel" value={null} />]
          }
        })()}
      </box>
    </box>
  )
}

export default function PairingDialog(gdkmonitor: Gdk.Monitor) {
  const prompt = current((c) => c?.prompt)

  return (
    <window
      name="bt-pairing"
      namespace="bt-pairing"
      class="BtPairing"
      gdkmonitor={gdkmonitor}
      visible={current((c) => c !== null)}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={prompt((p) => (needsKeyboard(p) ? Astal.Keymode.EXCLUSIVE : Astal.Keymode.ON_DEMAND))}
      application={app}
      $={(self) => {
        const keys = new Gtk.EventControllerKey()
        keys.connect("key-pressed", (_c, keyval) => {
          const c = current.get()
          if (keyval === Gdk.KEY_Escape && c) {
            answer(c.id, null)
            return true
          }
          return false
        })
        self.add_controller(keys)
      }}
    >
      <With value={current}>
        {(c) => (c ? <Body id={c.id} prompt={c.prompt} /> : <box />)}
      </With>
    </window>
  )
}
