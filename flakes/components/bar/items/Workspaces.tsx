import { Gdk } from "ags/gtk4"
import { createBinding, createComputed, For } from "ags"
import Hyprland from "gi://AstalHyprland"
import { config } from "../config"

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
      <box spacing={5}>
        <label class="ws-id" label={`${ws.id}`} />
        <box class="ws-apps" spacing={3} visible={clients((c) => c.length > 0)}>
          <For each={clients}>
            {(client: Hyprland.Client) => <AppIcon client={client} />}
          </For>
        </box>
      </box>
    </button>
  )
}

function resolveIcon(klass: string): string {
  if (!klass) return config.defaultAppIcon
  const key = klass.toLowerCase()
  // mapped override -> raw lowercased class (matches most desktop-file ids) -> default
  return config.taskbarIcons[key] ?? key
}

function AppIcon({ client }: { client: Hyprland.Client }) {
  const klass = createBinding(client, "class")
  return (
    <image class="app-icon" pixelSize={15} iconName={klass(resolveIcon)} />
  )
}
