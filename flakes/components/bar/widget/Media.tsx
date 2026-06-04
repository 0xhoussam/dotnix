import { Gtk } from "ags/gtk4"
import { createBinding, With, For } from "ags"
import AstalMpris from "gi://AstalMpris"

// Now-playing card(s). Only rendered when an MPRIS player is present, so the
// panel stays clean when nothing is playing.
export function Media() {
  const mpris = AstalMpris.get_default()
  const players = createBinding(mpris, "players")

  return (
    <box
      class="media"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
      visible={players((p) => p.length > 0)}
    >
      <For each={players}>{(p: AstalMpris.Player) => <MediaCard player={p} />}</For>
    </box>
  )
}

function MediaCard({ player }: { player: AstalMpris.Player }) {
  const title = createBinding(player, "title")
  const artist = createBinding(player, "artist")
  const cover = createBinding(player, "coverArt")
  const status = createBinding(player, "playbackStatus")
  const canNext = createBinding(player, "canGoNext")
  const canPrev = createBinding(player, "canGoPrevious")
  const playing = status((s) => s === AstalMpris.PlaybackStatus.PLAYING)

  return (
    <box class="media-card" spacing={12}>
      <With value={cover}>
        {(c: string) =>
          c ? (
            <image class="media-cover" file={c} pixelSize={56} />
          ) : (
            <image class="media-cover" iconName="audio-x-generic-symbolic" pixelSize={56} />
          )
        }
      </With>

      <box class="media-info" orientation={Gtk.Orientation.VERTICAL} hexpand>
        <label
          class="media-title"
          label={title((t) => t || "Unknown")}
          halign={Gtk.Align.START}
          xalign={0}
          maxWidthChars={24}
          ellipsize={3 /* END */}
        />
        <label
          class="media-artist"
          label={artist((a) => a || "")}
          visible={artist((a) => !!a)}
          halign={Gtk.Align.START}
          xalign={0}
          maxWidthChars={24}
          ellipsize={3}
        />

        <box class="media-controls" spacing={4}>
          <button
            class="media-btn"
            visible={canPrev}
            onClicked={() => player.previous()}
          >
            <image iconName="media-skip-backward-symbolic" pixelSize={16} />
          </button>
          <button class="media-btn media-play" onClicked={() => player.play_pause()}>
            <image
              iconName={playing((p) =>
                p ? "media-playback-pause-symbolic" : "media-playback-start-symbolic",
              )}
              pixelSize={16}
            />
          </button>
          <button class="media-btn" visible={canNext} onClicked={() => player.next()}>
            <image iconName="media-skip-forward-symbolic" pixelSize={16} />
          </button>
        </box>
      </box>
    </box>
  )
}
