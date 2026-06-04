import { Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import AstalNotifd from "gi://AstalNotifd"

function timeLabel(unix: number): string {
  if (!unix) return ""
  return GLib.DateTime.new_from_unix_local(unix).format("%H:%M") ?? ""
}

// `image`/`app_icon` may be a themed icon name or an absolute file path.
function ImageOrIcon({ value, size, css }: { value: string; size: number; css: string }) {
  if (value && value.startsWith("/")) {
    return <image class={css} file={value} pixelSize={size} />
  }
  return <image class={css} iconName={value || "dialog-information-symbolic"} pixelSize={size} />
}

// One notification card. Used both in the panel list and as a popup toast.
export function NotificationCard({ n }: { n: AstalNotifd.Notification }) {
  const urgency =
    n.urgency === AstalNotifd.Urgency.CRITICAL
      ? "critical"
      : n.urgency === AstalNotifd.Urgency.LOW
        ? "low"
        : "normal"

  return (
    <box class={`notif-card ${urgency}`} orientation={Gtk.Orientation.VERTICAL}>
      <box class="notif-head" spacing={6}>
        <ImageOrIcon value={n.appIcon || n.desktopEntry} size={16} css="notif-appicon" />
        <label class="notif-appname" label={n.appName || "Notification"} />
        <label class="notif-time" label={timeLabel(n.time)} hexpand halign={1 /* START */} />
        <button class="notif-close" onClicked={() => n.dismiss()} valign={1}>
          <image iconName="window-close-symbolic" pixelSize={14} />
        </button>
      </box>

      <box class="notif-content" spacing={10}>
        {n.image ? <ImageOrIcon value={n.image} size={42} css="notif-image" /> : <box />}
        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
          <label
            class="notif-summary"
            label={n.summary || ""}
            halign={1}
            xalign={0}
            wrap
            maxWidthChars={36}
          />
          <label
            class="notif-body"
            label={n.body || ""}
            visible={!!n.body}
            halign={1}
            xalign={0}
            wrap
            maxWidthChars={36}
          />
        </box>
      </box>

      {(() => {
        // Skip the implicit "default" action and blank labels (they render as
        // an empty button otherwise).
        const actions = n.get_actions().filter((a) => a.id !== "default" && a.label?.trim())
        return actions.length > 0 ? (
          <box class="notif-actions" spacing={6} homogeneous>
            {actions.map((a) => (
              <button class="notif-action" onClicked={() => n.invoke(a.id)}>
                <label label={a.label} />
              </button>
            ))}
          </box>
        ) : (
          <box />
        )
      })()}
    </box>
  )
}
