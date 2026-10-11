# components

AGS (Astal/GTK) UI components for my Linux dotfiles.

Built with [AGS](https://aylur.github.io/ags/) via Nix flakes.

## Contents

| Path        | GTK | Description                                          |
| ----------- | --- | ---------------------------------------------------- |
| `app.tsx`   | 4   | Top bar (example).                                   |
| `lock/`     | 4   | Secure lock screen (`ext-session-lock-v1` + PAM).    |

Both are GTK 4; the lock uses `Gtk4SessionLock` from `gtk4-layer-shell`.
They are independent processes.

### Lock screen

- Portable across Wayland compositors (Hyprland, Sway, niri, KDE, …) via the
  `ext-session-lock-v1` protocol — the compositor blanks all outputs, no bypass.
- PAM authentication via `AstalAuth` (service in `lock/config.ts`, default
  `swaylock`).
- Live wallpaper: `lockWallpaper` argument of `default.nix` (set in the
  top-level `flake.nix`), baked into the wrapper as `LOCK_WALLPAPER`. Video
  is looped, muted, decoded once for all monitors (VA-API hardware decode)
  and paused after `IDLE_PAUSE_SECONDS` without input; images work too.
- Orbitron HUD: clock + date top-left, password underline bottom-right
  (caps-lock / PAM messages, fail-shake), session name and Restart /
  Shut down (click twice) on the bottom line.

## Develop

```sh
nix develop                 # enter dev shell (ags CLI + libraries)

ags run .                   # run the bar
ags run lock                # run the lock screen
```

> The lock screen really locks the session. To work on the design without
> locking: `LOCK_PREVIEW=1 lock-screen` (Ctrl+Escape quits;
> `LOCK_WALLPAPER=/path/to/video.mp4` overrides the wallpaper). Escape hatch
> for a real lock: switch to a TTY (Ctrl+Alt+F2), `pkill -f lock-screen`,
> switch back.

## Build

```sh
nix build .#default         # bar binary
nix build .#lock            # lock-screen binary
```
