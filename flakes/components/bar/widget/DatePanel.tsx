import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"
import { createBinding, createState, For } from "ags"
import { createPoll } from "ags/time"
import GLib from "gi://GLib"
import AstalNotifd from "gi://AstalNotifd"
import { NotificationCard } from "./Notification"
import { Media } from "./Media"
import { config } from "../config"
import { panelOpen, closePanel } from "../state"

// GNOME-style shade: notifications (left) + calendar / events / world clocks
// (right). Fullscreen transparent overlay; click outside or Escape to close.
export default function DatePanel(gdkmonitor: Gdk.Monitor) {
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      name="datepanel"
      namespace="datepanel"
      class="DatePanelWindow"
      gdkmonitor={gdkmonitor}
      visible={panelOpen}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      exclusivity={Astal.Exclusivity.NONE}
      application={app}
      $={(self) => {
        const keys = new Gtk.EventControllerKey()
        keys.connect("key-pressed", (_c, keyval) => {
          if (keyval === Gdk.KEY_Escape) closePanel()
          return false
        })
        self.add_controller(keys)
      }}
    >
      <overlay>
        <button class="panel-backdrop" hexpand vexpand onClicked={closePanel} />
        <revealer
          $type="overlay"
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.START}
          transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
          transitionDuration={220}
          revealChild={panelOpen}
        >
          <box class="date-panel" orientation={Gtk.Orientation.HORIZONTAL}>
            <NotificationColumn />
            <CalendarColumn />
          </box>
        </revealer>
      </overlay>
    </window>
  )
}

function NotificationColumn() {
  const notifd = AstalNotifd.get_default()
  // The `notifications` property doesn't emit a reliable notify, so drive the
  // list off the notified/resolved signals instead.
  const [items, setItems] = createState<AstalNotifd.Notification[]>(notifd.get_notifications())
  const refresh = () => setItems(notifd.get_notifications())
  notifd.connect("notified", refresh)
  notifd.connect("resolved", refresh)

  const dnd = createBinding(notifd, "dontDisturb")
  const sorted = items((l) => [...l].sort((a, b) => b.time - a.time))

  return (
    <box class="notif-column" orientation={Gtk.Orientation.VERTICAL}>
      <Media />
      <Gtk.ScrolledWindow vexpand hscrollbarPolicy={Gtk.PolicyType.NEVER}>
        <box class="notif-list" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <label
            class="notif-empty"
            label="No Notifications"
            vexpand
            valign={Gtk.Align.CENTER}
            visible={items((l) => l.length === 0)}
          />
          <For each={sorted}>{(n: AstalNotifd.Notification) => <NotificationCard n={n} />}</For>
        </box>
      </Gtk.ScrolledWindow>

      <box class="notif-footer" spacing={8}>
        <label label="Do Not Disturb" hexpand halign={Gtk.Align.START} />
        <switch
          class="dnd-switch"
          active={dnd}
          $={(self) =>
            self.connect("notify::active", () => {
              if (self.active !== notifd.dontDisturb) notifd.dontDisturb = self.active
            })
          }
        />
        <button
          class="clear-btn"
          // copy first: dismiss() mutates the live list mid-iteration
          onClicked={() => [...notifd.get_notifications()].forEach((n) => n.dismiss())}
        >
          <label label="Clear" />
        </button>
      </box>
    </box>
  )
}

function CalendarColumn() {
  // Single shared 10s tick drives the header date and every world clock,
  // instead of one timer per label.
  const now = createPoll(GLib.DateTime.new_now_local(), 10_000, () =>
    GLib.DateTime.new_now_local(),
  )

  // Resolve timezones once.
  const clocks = config.worldClocks.map((c) => ({
    city: c.label,
    zone: GLib.TimeZone.new_identifier(c.tz),
  }))

  return (
    <box class="cal-column" orientation={Gtk.Orientation.VERTICAL} spacing={12}>
      <box class="cal-header" orientation={Gtk.Orientation.VERTICAL}>
        <label class="cal-weekday" label={now((t) => t.format("%A")!)} halign={Gtk.Align.START} />
        <label class="cal-date" label={now((t) => t.format("%B %-d %Y")!)} halign={Gtk.Align.START} />
      </box>

      <Gtk.Calendar class="calendar" />

      <box class="cal-card cal-events" orientation={Gtk.Orientation.VERTICAL}>
        <label class="cal-card-title" label="Today" halign={Gtk.Align.START} />
        <label class="cal-card-sub" label="No Events" halign={Gtk.Align.START} />
      </box>

      <box class="cal-card world-clocks" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
        <label class="cal-card-title" label="World Clocks" halign={Gtk.Align.START} />
        {clocks.map(({ city, zone }) => (
          <box class="world-row" spacing={8}>
            <label class="world-city" label={city} hexpand halign={Gtk.Align.START} />
            <label
              class="world-time"
              label={now((t) => (zone ? t.to_timezone(zone) : t).format("%H:%M")!)}
            />
          </box>
        ))}
      </box>
    </box>
  )
}
