import { Gtk } from "ags/gtk4"
import { createBinding } from "ags"
import AstalWp from "gi://AstalWp"

// Default-speaker volume. Click toggles mute, scroll adjusts level.
export function Volume() {
  const speaker = AstalWp.get_default()?.audio.defaultSpeaker
  if (!speaker) return <box visible={false} />

  const icon = createBinding(speaker, "volumeIcon")
  const vol = createBinding(speaker, "volume")

  return (
    <button
      class="volume"
      onClicked={() => speaker.set_mute(!speaker.mute)}
      tooltipText={vol((v) => `Volume ${Math.round(v * 100)}%`)}
      $={(self) => {
        const scroll = new Gtk.EventControllerScroll()
        scroll.set_flags(Gtk.EventControllerScrollFlags.VERTICAL)
        scroll.connect("scroll", (_c, _dx, dy) => {
          speaker.volume = Math.max(0, Math.min(1, speaker.volume - dy * 0.05))
          speaker.mute = false
          return true
        })
        self.add_controller(scroll)
      }}
    >
      <box spacing={5}>
        <image iconName={icon} pixelSize={16} />
        <label label={vol((v) => `${Math.round(v * 100)}%`)} />
      </box>
    </button>
  )
}
