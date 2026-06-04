# components

AGS (Astal/GTK) UI components for my Linux dotfiles.

Built with [AGS](https://aylur.github.io/ags/) via Nix flakes.

## Contents

| Path        | GTK | Description                                          |
| ----------- | --- | ---------------------------------------------------- |
| `app.tsx`   | 4   | Top bar (example).                                   |
| `lock/`     | 3   | Secure lock screen (`ext-session-lock-v1` + PAM).    |

The lock screen lives on GTK 3 because the only `ext-session-lock-v1`
binding with GObject introspection (`gtk-session-lock`) is GTK 3. The bar
stays on GTK 4. They are independent processes.

### Lock screen

- Portable across Wayland compositors (Hyprland, Sway, niri, KDE, …) via the
  `ext-session-lock-v1` protocol — the compositor blanks all outputs, no bypass.
- PAM authentication via `AstalAuth` (service configurable in
  `lock/widget/LoginBox.tsx`, default `swaylock`).
- Clock, avatar (`~/.face`), password field with fail-shake, and top-right
  chips: keyboard layout (Hyprland), WiFi, battery.
- Wallpaper path set in `lock/config.ts` (PNG/JPEG; webp needs
  `webp-pixbuf-loader`).

## Develop

```sh
nix develop                 # enter dev shell (ags CLI + libraries)

ags run .                   # run the bar
ags run lock                # run the lock screen
```

> The lock screen really locks the session. Escape hatch while testing:
> switch to a TTY (Ctrl+Alt+F2), `pkill -f lock-screen`, switch back.

## Build

```sh
nix build .#default         # bar binary
nix build .#lock            # lock-screen binary
```
