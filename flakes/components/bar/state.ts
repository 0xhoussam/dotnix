import { createState } from "ags"

// Whether the GNOME-style date/notification panel is open.
export const [panelOpen, setPanelOpen] = createState(false)

export function togglePanel() {
  setPanelOpen(!panelOpen.get())
}

export function closePanel() {
  setPanelOpen(false)
}
