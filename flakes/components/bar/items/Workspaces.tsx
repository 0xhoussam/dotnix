import { Gdk, Gtk } from "ags/gtk4"
import { createBinding, createComputed, For } from "ags"
import Hyprland from "gi://AstalHyprland"

// Hyprland workspaces as dots: a faint dot per workspace, brighter when
// occupied, and an elongated accent pill for the focused one.
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
    const c = ["ws-dot"]
    if (fw && fw.id === ws.id) c.push("active")
    c.push(occupied ? "occupied" : "empty")
    return c.join(" ")
  })

  // valign center stops the button stretching to the full bar height, so the
  // dot keeps its min-height (otherwise border-radius makes a tall bar).
  return (
    <button
      class={cls}
      valign={Gtk.Align.CENTER}
      onClicked={() => ws.focus()}
      tooltipText={`Workspace ${ws.id}`}
    />
  )
}
