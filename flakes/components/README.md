# components

The desktop shell for my Hyprland setup: a bar with panels, notifications, an
on-screen display and a lock screen. Built with
[Quickshell](https://quickshell.org/) (QML) and a small Rust sidecar, via Nix.

The previous AGS (Astal/GTK) implementation was removed after the port; it is
in git history. See `docs/MIGRATION.md` for how the port went,
`docs/VOLUME-PANEL.md` for the volume panel design and `docs/ROADMAP.md` for
the follow-up work and its checklist.

## Contents

| Path          | Output (`nix build .#…`)  | Description |
| ------------- | ------------------------- | ----------- |
| `shell/`      | `qs-shell` (`my-shell`)   | Bar, panels, notifications, OSD (Quickshell QML). |
| `lockscreen/` | `qs-lock` (`lock-screen`) | Lock screen on `ext-session-lock-v1` with PAM. |
| `agents/`     | `shell-agents`            | Rust sidecar: BlueZ pairing agent, OBEX, NetworkManager model and secret agent, generic D-Bus proxy. |

`shell/` is organised by feature: `bar/` (bar and its items), `widgets/`
(shared UI: `PopupCard`, `ListRow`, `Toggle`, `Chip`, `Slider`, notifications,
date panel), `audio/`, `bluetooth/`, `network/`, plus the singletons `Theme`,
`Config`, `UiState`, `Notifs` and `Agents`.

The sidecar talks to the QML side with JSON lines on stdio and is started and
supervised by `shell/Agents.qml`. It exits (cancelling pending prompts) when
the shell exits.

## Run

```sh
nix run .#qs-shell                     # the bar (needs the sidecar's agent slots free)
SHELL_AGENTS_OFF=1 nix run .#qs-shell  # no sidecar: safe next to another bar
SHELL_AGENTS_SKIP=bluetooth,obex,secrets nix run .#qs-shell   # network model only
LOCK_PREVIEW=1 nix run .#qs-lock       # lock screen design preview (no locking)
```

The user unit is `quickshell-bar` (`shared/desktop/hypr/shell.nix`). The lock
screen is started by hypridle and the Hyprland keybinds.

> The real lock screen locks the session. Escape hatch: switch to a TTY
> (Ctrl+Alt+F2), `pkill -f lock-screen`, switch back. In preview mode
> Ctrl+Escape quits. `LOCK_WALLPAPER=/path/to/video.mp4` overrides the
> wallpaper.

## Develop

```sh
nix develop                              # quickshell, qmlls and qmllint
cargo test --manifest-path agents/Cargo.toml
nix build .#checks.x86_64-linux.qmllint  # lint report (warnings are not fatal yet)
```

Hyprland's config is Lua here: `hyprctl dispatch` takes a Lua dispatcher
(`hl.dsp.focus({ workspace = 2 })`), not `workspace 2`.

## State and settings

Small JSON files in `~/.config/my-shell/`: `bluetooth.json`, `network.json`,
`audio.json` (notification and option toggles). The bar's position, size,
autohide and modules are in `shell/Config.qml` (rebuild to change).

## Build

```sh
nix build .#qs-shell .#qs-lock .#shell-agents
```

`shell-agents` runs its unit tests during the build. The wrappers put the tools
the shell runs (`brightnessctl`, `wpctl`, `cliphist`, `tuned-adm`, …) on `PATH`,
because a systemd user unit's `PATH` is short.
