# Roadmap: Quickshell follow-up work

This file is the source of truth for the work below. Tick items as they are committed (one commit per item or small group).

## Live state of the session (update when it changes)

- `ags-bar` is stopped. The old bar is not running.
- The Quickshell bar is a transient process started by hand (`my-shell`, agents enabled), not a systemd service. It does not survive logout.
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
- [ ] IPC handlers (`IpcHandler`) for date panel, volume panel, quick settings, OSD triggers; check how `qs ipc` selects the instance.
- [ ] General OSD (volume, brightness, mic mute, caps lock, keyboard layout); brightness OSD triggered from the keybind via IPC, not a sysfs watch.

### Findings while preparing
- `mpvpaper` is already started with `-p` (auto-pause when hidden). `-a FULL` would also pause on fullscreen windows; that is a one-flag change in the wallpaper unit. Battery handling is separate.
- The terminal check for text entry in a `PopupWindow`, `tuned-adm` without polkit, and acpid overriding manual profiles are still open (see section 0).

### 3. High-value features
- [ ] Quick Settings panel (replaces the Settings stub): brightness, night light, power profile, Do Not Disturb, Wi-Fi and Bluetooth toggles, caffeine, screenshot, power menu.
- [ ] Battery popup (time remaining, rate, health, power profile).
- [ ] Workspace window icons (`taskbarIcons`), urgent state, scroll to switch.
- [ ] Wallpaper power control (pause `mpvpaper` on battery / fullscreen); check `mpvpaper --help` for built-in auto-pause first.

### 4. Further features
- [ ] Now-playing pill in the bar.
- [ ] Notification centre: group by app, scheduled Do Not Disturb, expiry and progress hints, persisted history.
- [ ] System stats popup (CPU, RAM, temperature, network speed), read only while open.
- [ ] Clipboard: search, image preview, delete single entries, pinning.
- [ ] Screen recording with a bar indicator (no recorder installed yet; needs one added to the config).
- [ ] Calendar events and weather in the date panel (open question: weather source and location, calendar source).
- [ ] Lock screen extras (media, battery, layout, notification count via shared state); fingerprint only if `fprintd` is enrolled.
- [ ] Theming (accent source, optional light mode).

## Open questions for the user
- Weather: third-party call (wttr.in or open-meteo), needs a location. Which, and where?
- Calendar source: which is installed / used?
- Recorder: add `gpu-screen-recorder` or `wf-recorder`?
- Fingerprint: is `fprintd` enrolled?
