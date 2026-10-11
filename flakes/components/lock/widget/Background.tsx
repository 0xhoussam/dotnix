import { Gdk, Gtk } from "ags/gtk4"
import GLib from "gi://GLib"
import { IDLE_PAUSE_SECONDS, WALLPAPER } from "../config"

// One wallpaper paintable shared by every monitor's surface, so a video is
// decoded once no matter how many outputs are locked.

const VIDEO = /\.(mp4|webm|mkv|mov|m4v)$/i

let paintable: Gdk.Paintable | null | undefined
let media: Gtk.MediaFile | null = null

function load(): Gdk.Paintable | null {
  const path = WALLPAPER
  if (!path || !GLib.file_test(path, GLib.FileTest.EXISTS)) return null
  try {
    if (VIDEO.test(path)) {
      media = Gtk.MediaFile.new_for_filename(path)
      media.loop = true
      media.muted = true
      media.connect("notify::error", () => console.error("lock: video error:", media?.error?.message))
      media.play()
      return media
    }
    return Gdk.Texture.new_from_filename(path)
  } catch (e) {
    console.error("lock: failed to load wallpaper", path, e)
    return null
  }
}

export function wallpaper(): Gdk.Paintable | null {
  if (paintable === undefined) paintable = load()
  return paintable
}

// ---- idle pause ------------------------------------------------------------------

let lastInput = GLib.get_monotonic_time()
let pausedForIdle = false
let idleTimer = 0

export function noteInput() {
  lastInput = GLib.get_monotonic_time()
  if (pausedForIdle && media) {
    pausedForIdle = false
    media.play()
  }
}

export function startIdlePause() {
  if (idleTimer || !media) return
  idleTimer = GLib.timeout_add_seconds(GLib.PRIORITY_LOW, 10, () => {
    const idle = (GLib.get_monotonic_time() - lastInput) / 1_000_000
    if (media && !pausedForIdle && media.playing && idle >= IDLE_PAUSE_SECONDS) {
      pausedForIdle = true
      media.pause()
    }
    return GLib.SOURCE_CONTINUE
  })
}

export function Background() {
  const p = wallpaper()
  return p ? (
    <Gtk.Picture class="lock-bg" paintable={p} contentFit={Gtk.ContentFit.COVER} canShrink hexpand vexpand />
  ) : (
    <box class="lock-bg lock-bg-fallback" hexpand vexpand />
  )
}
