import { Gdk } from "ags/gtk4"
import { createBinding, createComputed, For } from "ags"
import Hyprland from "gi://AstalHyprland"

// Hyprland workspaces with per-workspace app icons (icon = window class).
export function Workspaces({ gdkmonitor: _gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const hypr = Hyprland.get_default()
  const focused = createBinding(hypr, "focusedWorkspace")
  const workspaces = createBinding(hypr, "workspaces")

  // Drop special (negative id) workspaces, sort ascending.
  const sorted = workspaces((ws) =>
    ws.filter((w) => w.id > 0).sort((a, b) => a.id - b.id),
  )

  return (
    <box class="workspaces" spacing={4}>
      <For each={sorted}>
        {(ws: Hyprland.Workspace) => (
          <WorkspaceButton ws={ws} focused={focused} />
        )}
      </For>
    </box>
  )
}

function WorkspaceButton({
  ws,
  focused,
}: {
  ws: Hyprland.Workspace
  focused: ReturnType<typeof createBinding<Hyprland.Workspace>>
}) {
  const clients = createBinding(ws, "clients")

  const cls = createComputed(() => {
    const fw = focused()
    const occupied = clients().length > 0
    const c = ["workspace"]
    if (fw && fw.id === ws.id) c.push("active")
    c.push(occupied ? "occupied" : "empty")
    return c.join(" ")
  })

  return (
    <button class={cls} onClicked={() => ws.focus()} tooltipText={`Workspace ${ws.id}`}>
      <label class="ws-id" label={`${ws.id}`} />
    </button>
  )
}
