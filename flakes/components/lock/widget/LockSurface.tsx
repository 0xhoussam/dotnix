/** @jsxImportSource ags/gtk3 */
import Gtk from "gi://Gtk?version=3.0"
import Clock from "./Clock"
import LoginBox from "./LoginBox"
import Indicators from "./Indicators"

// One surface per monitor. Indicators top-right, clock top-center,
// login box bottom-center. Only the primary monitor gets the login + chips.
export default function LockSurface(primary: boolean, onSuccess: () => void) {
  return (
    <box class="lock-surface" hexpand vexpand>
      <box class="lock-layout" vertical hexpand vexpand>
        {primary ? <Indicators /> : <box />}
        <Clock />
        <box vexpand />
        {primary ? LoginBox(onSuccess) : <box />}
      </box>
    </box>
  )
}
