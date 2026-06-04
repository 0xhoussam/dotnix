import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { createState, For } from "ags"
import { timeout } from "ags/time"
import AstalNotifd from "gi://AstalNotifd"
import { NotificationCard } from "./Notification"

// Transient toast popups, top-right. New notifications appear here and
// auto-dismiss after a few seconds (critical ones stay until acted on).
export default function NotificationPopups(gdkmonitor: Gdk.Monitor) {
  const { TOP, RIGHT } = Astal.WindowAnchor
  const notifd = AstalNotifd.get_default()
  const [popups, setPopups] = createState<AstalNotifd.Notification[]>([])

  const remove = (id: number) => setPopups(popups.get().filter((p) => p.id !== id))

  notifd.connect("notified", (_n, id) => {
    if (notifd.dontDisturb) return
    const n = notifd.get_notification(id)
    if (!n) return
    setPopups([n, ...popups.get().filter((p) => p.id !== id)])
    // Always auto-hide the toast; the full notification stays in the panel.
    timeout(n.urgency === AstalNotifd.Urgency.CRITICAL ? 10000 : 5000, () => remove(id))
  })

  notifd.connect("resolved", (_n, id) => remove(id))

  return (
    <window
      name="notifpopups"
      namespace="notifpopups"
      class="NotifPopups"
      gdkmonitor={gdkmonitor}
      visible={popups((p) => p.length > 0)}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | RIGHT}
      exclusivity={Astal.Exclusivity.NONE}
      application={app}
    >
      <box class="popup-list" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        <For each={popups}>
          {(n: AstalNotifd.Notification) => (
            <revealer
              transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
              transitionDuration={250}
              $={(self) => self.connect("map", () => (self.revealChild = true))}
            >
              <NotificationCard n={n} />
            </revealer>
          )}
        </For>
      </box>
    </window>
  )
}
