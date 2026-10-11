import { createState } from "ags"
import { execAsync, subprocess } from "ags/process"

// Bluetooth kill-switch state (blueman's KillSwitch plugin). A hard block
// (hardware switch / airplane key) can't be undone from software; a soft
// block is lifted before powering the adapter on.

export interface RfkillState {
  soft: boolean
  hard: boolean
}

export const [rfkill, setRfkill] = createState<RfkillState>({ soft: false, hard: false })

async function refresh() {
  try {
    const out = await execAsync(["rfkill", "-J", "-o", "TYPE,SOFT,HARD"])
    const devs: { type: string; soft: string; hard: string }[] = JSON.parse(out).rfkilldevices ?? []
    const bt = devs.filter((d) => d.type === "bluetooth")
    setRfkill({
      soft: bt.length > 0 && bt.every((d) => d.soft === "blocked"),
      hard: bt.length > 0 && bt.every((d) => d.hard === "blocked"),
    })
  } catch {
    // rfkill missing: assume unblocked
  }
}

let started = false

export function startRfkillWatch() {
  if (started) return
  started = true
  void refresh()
  // `rfkill event` prints a line on every change (and the current state at start)
  subprocess(["rfkill", "event"], () => void refresh(), () => {})
}

export async function unblock(): Promise<void> {
  if (!rfkill.get().soft) return
  await execAsync(["rfkill", "unblock", "bluetooth"])
  await refresh()
}
