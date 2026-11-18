# Roadmap: Quickshell follow-up work

This file is the source of truth for the work below. Tick items as they are committed (one commit per item or small group).

## Live state of the session (update when it changes)

- `ags-bar` is stopped. The old bar is not running.
- The Quickshell bar is a transient process started by hand (`my-shell`, agents enabled), not a systemd service. It does not survive logout. It is restarted after each batch (kill the `quickshell -p .../qs-shell/share` process, start the new `my-shell`).
- `home-manager switch --flake .#pride` has NOT been run. The committed config (`06b907a`) already points `hyprland.nix`, `hypridle.nix` and the unit at Quickshell, but none of that is live until the switch. New keybinds only go live at the switch.
- The real lock screen (`WlSessionLock`) has never been run, only `LOCK_PREVIEW=1`.
- AGS code stays in the repo (the user asked to keep it). Removing it is the last item and needs an explicit yes.
- The network panel is the user's only network UI right now.

## Decisions from the user

- Build: Quick Settings, IPC handlers, general OSD, battery popup, workspace window icons, wallpaper power control; now-playing pill, notification centre upgrades, system stats popup, clipboard upgrades, screen recording, calendar events and weather, lock screen extras, theming; all cleanup items.
- Not wanted: live config file, active window title in the bar, launcher replacement.
- New toggles persist as small state files (like `audio.json`), not a general config.

## Rules for this work

- No always-on polling or process spawns in the bar. Read stats only while a popup is open.
- Hard dependencies go on the wrapper's PATH in `default.nix` (the unit environment is not the interactive shell's). Known: `brightnessctl`, `wpctl`, `pw-dump`, `cliphist`, `wl-copy`, `tuned-adm`, `systemd-inhibit`, `rfkill`.
- Notification history on disk holds message bodies: state directory, mode 0600, size cap.
- Run the real lock once (TTY escape ready: Ctrl+Alt+F2, `pkill -f lock-screen`) before adding to it.
- After each batch: rebuild, restart the live bar, hand the user a short list of things to click.

## Checklist

### 0. Correctness
- [x] `wait_active` treated "connection not loaded yet" as failure and would delete a new connection; fixed with `wait_status`, tested.
- [x] Sidecar stderr visible in the Quickshell log.
- [x] `hyprctl dispatch` syntax: legacy `workspace N` FAILS under Hyprland 0.56 Lua config; `hl.dsp.focus({ workspace = N })` works. The workspace dots were broken (Quickshell's `activate()` uses the legacy form); now use the Lua form. Use Lua dispatchers for logout/scroll too.
- [ ] Check `tuned-adm` works without a polkit prompt, and that acpid (`hosts/bystial/power.nix`) overrides manual profile choices.
- [ ] Check text entry inside a `PopupWindow` (needed for clipboard search).
- [x] Hard dependencies on the wrapper PATH (`shellTools` in `default.nix`, plus `/run/current-system/sw/bin` as a suffix). The systemd user PATH has no `/run/current-system/sw/bin`.

### 1. Cleanup
- [x] Theme tokens for the hard-coded colours (a few one-off alphas remain in Slider/Toggle/Media).
- [x] `PopupCard` component (anchor, focus grab, derived open state via `UiState.register`) used by clipboard, Bluetooth, network, volume; tray menus register too.
- [x] Date panel uses `Toggle`, not the default Qt `Switch`.
- [x] Bluetooth `DeviceRow` uses `ListRow`.
- [x] `qmllint` flake check (`checks.x86_64-linux.qmllint`); `cargo test` already runs in the `shell-agents` build. The qmllint report is very noisy (~2,900 warnings, mostly unresolved Quickshell types and unqualified access, no errors), so it is not a useful gate yet.
- [x] README rewritten for Quickshell.
- [ ] Remove AGS code and the `ags` input: ONLY after an explicit yes, and after the real lock has been used.

### 2. Foundations
- [x] IPC: `IpcHandler` target `shell` with `toggle <date|volume|quick|bluetooth|network|clipboard>` (focused monitor only) and `osd brightness`. `shell-ctl` (in the `qs-shell` package) wraps `qs ipc --path <config> call`, so `shell-ctl shell toggle volume`. Only the brightness keybinds use it so far; bind the rest to keys you like.
- [x] General OSD (`widgets/Osd.qml`): volume, mic mute, keyboard layout (automatic), brightness (IPC from the keybinds). Caps lock OSD NOT done: there is no event source without polling or a Caps_Lock keybind.

### Findings while preparing
- `mpvpaper` is already started with `-p` (auto-pause when hidden). `-a FULL` would also pause on fullscreen windows; that is a one-flag change in the wallpaper unit. Battery handling is separate.
- The terminal check for text entry in a `PopupWindow`, `tuned-adm` without polkit, and acpid overriding manual profiles are still open (see section 0).

### 3. High-value features
- [x] Quick Settings panel (`bar/items/Settings.qml`, `quick/QuickService.qml`): brightness and keyboard backlight, Wi-Fi / Bluetooth / Do Not Disturb / Night Light (hyprsunset unit) / Caffeine / screen recording tiles, tuned power profiles, screenshots (own overlay, `screenshot/`), session menu (lock, suspend, log out, restart, shut down; destructive ones need a second click). `wf-recorder` is now on the shell's PATH (no system install needed). NOT verified live: `tuned-adm profile` without a polkit prompt, recording, logout dispatch.
- [x] Battery popup (charge, state, time left, power draw, energy, health, tuned profile chips).
- [x] Workspaces: window icons (up to 3 + N) via `Config.taskbarIcons` -> desktop entry -> class, focused pill, urgent tint, scroll to switch (Lua dispatch).
- [x] Wallpaper power control: `-a FULL` added to the mpvpaper unit (pauses behind fullscreen windows; live after `home-manager switch`); the shell SIGSTOPs mpvpaper on battery (last frame stays) and SIGCONTs on AC; a Quick Settings tile toggles it (`wallpaper.json`).

### 4. Further features (notifications now stack the same app's notifications behind the newest card)
- [x] Now-playing pill (click play/pause, middle next, right opens the date panel).
- [x] Notification centre: grouped by app (collapse, clear group), quiet hours (toasts held back; steppers in the panel), sender timeouts honoured, progress hint bar, history kept across restarts (`~/.local/state/my-shell/notifications.json`, mode 0600, 200 entries / 14 days) and DND persisted (`notifications.json` in config).
- [x] System stats popup (CPU with history, memory, swap, disk, temperature, network); sampled once a second only while open.
- [x] Clipboard (`widgets/ClipboardPanel.qml`, a centered layer window with exclusive keyboard focus, opened by the bar icon or `shell-ctl shell toggle clipboard`): search, Up/Down/Enter/Delete/Esc, image thumbnails (decoded into tmpfs, removed on close), delete single entries, pinned text snippets (`~/.local/state/my-shell/clipboard-pins.json`, mode 0600, max 30). Not looked at on screen (it shows the user's clipboard history); no errors on open/close.
- [ ] Screen recording with a bar indicator (no recorder installed yet; needs one added to the config).
- [x] Weather (wttr.in by IP, `~/.config/my-shell/weather.txt` overrides the place) and Google Calendar events (secret iCal address in `~/.config/my-shell/calendar.url`; the Rust sidecar fetches with curl and expands recurring events; today + 2 days). Needs the user to paste the calendar address. Fixed the empty month grid.
- [ ] Lock screen extras (media, battery, layout, notification count via shared state); fingerprint only if `fprintd` is enrolled.
- [x] Theming (see also `/STYLIX-PLAN.md`: adopting Stylix system-wide, with a Quickshell bridge in its phase 4): dark / light and six accent colours (Quick Settings, `theme.json`), all colours are `Theme` tokens. Accent from the wallpaper is NOT done (needs a colour-extraction tool). The lock screen keeps its own dark HUD.

## Answers from the user
- Weather: wttr.in. Calendar: Google Calendar (no calendar app installed); use the secret iCal address. No fingerprint reader (skip fingerprint on the lock).

## Open questions for the user
- Weather: third-party call (wttr.in or open-meteo), needs a location. Which, and where?
- Calendar source: which is installed / used?
- Recorder: add `gpu-screen-recorder` or `wf-recorder`?
- Fingerprint: is `fprintd` enrolled?
