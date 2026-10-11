// Lock screen configuration.
import GLib from "gi://GLib"

// Background: a video (looped, muted; anything GStreamer decodes) or an
// image. Set by Nix through the wrapper (lockWallpaper in default.nix, passed
// from flake.nix); unset or missing = dark gradient.
export const WALLPAPER = GLib.getenv("LOCK_WALLPAPER") ?? ""

// Pause the video after this long without input (saves battery while the
// screen sits locked); any key or pointer motion resumes it.
export const IDLE_PAUSE_SECONDS = 180

// PAM service to authenticate against. Must exist in /etc/pam.d.
export const PAM_SERVICE = "swaylock"
