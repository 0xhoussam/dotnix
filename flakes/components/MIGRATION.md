# Migration plan: AGS (Astal/GTK4) to Quickshell

Status: option A (Rust sidecar) chosen. Phases 1-4 implemented in `shell/`. Phase 5 started: `agents/` is a Rust crate (`shell-agents`, pure-Rust D-Bus via zbus, no libnm/libsecret) with the shared one-at-a-time prompter and the BlueZ pairing agent. `shell/Agents.qml` bridges it over JSON lines on stdio; `shell/bluetooth/PairingDialog.qml` renders the prompts.

Verified: `cargo test` (prompter semantics); the agent against a private D-Bus daemon (confirm, reject, passkey, and UI-gone mid-prompt replies `Canceled`); the dialog renders from a fake sidecar. Not verified: registration with the real bluetoothd (needs `ags-bar` stopped, since the default agent slot is exclusive), the Bluetooth panel (not written), OBEX, anything in phase 6.

Findings from the Quickshell v0.3.2 type pages: `Quickshell.Bluetooth` covers adapters and devices (pair, connect, forget, trusted, battery, icon, wake) but no agent or OBEX. `Quickshell.Networking` has devices, `WifiNetwork.connectWithPsk`, `NMSettings`, and no 802.1X, VPN, hotspot or secret agent, so the network sidecar will own the whole model, not only the secret agent.

Phase 7 (lock screen) implemented in `lockscreen/`, built as `.#qs-lock` (`lock-screen` wrapper: single-instance via `qs -n`, Orbitron via FONTCONFIG_FILE, QtMultimedia added to the Qt paths). `LOCK_PREVIEW=1` ran with the video wallpaper and a PAM login that succeeded. NOT tested: the real `WlSessionLock` path (lock, wrong password, suspend/resume, kill and relaunch, hypridle path). Differences from AGS: caps lock is read from the keyboard LED in sysfs, and with several monitors each surface decodes its own copy of the video.

Test without hijacking the live agents: `SHELL_AGENTS_OFF=1 my-shell`.

Deviation from the plan: no new flake input. nixpkgs already ships `quickshell` 0.3.2, so `default.nix` uses `pkgs.quickshell` and `flake.nix` only gained the `qs-shell` package entry. The `State` singleton is named `UiState` because `State` clashes with the QtQuick type.

## 1. Goal and scope

Replace the two AGS-built binaries in this flake with Quickshell (QML) equivalents:

| Today | Output | Role |
| --- | --- | --- |
| `app.tsx` + `bar/` | `my-shell` (systemd user unit `ags-bar`) | Bar, date panel, notification popups, screen corners, Bluetooth and network panels and agents |
| `lock/` | `lock-screen` | `ext-session-lock-v1` lock screen with PAM and video wallpaper |

The migration is about 8,300 lines of TS/TSX/SCSS. The Bluetooth and network directories hold 5,594 of them: 2,972 lines of `.ts` logic (agents, libnm connection building, OBEX, helpers) and the rest `.tsx` UI. The SCSS is 1,212 lines in total.

Non-goals: redesigning the look, changing `bar/config.ts` semantics, changing the Hyprland and hypridle integration (they only call the `lock-screen` binary and run the bar unit).

## 2. Key finding: Quickshell does not replace every Astal library

Module names below were checked against the Quickshell v0.3.2 docs module list (https://quickshell.org/docs/v0.3.2/types/). What each module can do (properties, signals) is NOT verified; phase 0 checks that.

Pin Quickshell v0.3.x or newer. `Quickshell.Bluetooth` and `Quickshell.Networking` are in the v0.3.2 list but not in the v0.1.0 list. Check that your nixpkgs or flake input provides it.

| Astal lib used | Quickshell module (v0.3.2 list) | Gap |
| --- | --- | --- |
| `AstalHyprland` | `Quickshell.Hyprland` | Keyboard layout comes from the raw `activelayout` IPC event (verify it is exposed). |
| `AstalWp` | `Quickshell.Services.Pipewire` | None expected |
| `AstalMpris` | `Quickshell.Services.Mpris` | None |
| `AstalNotifd` | `Quickshell.Services.Notifications` | None expected |
| `AstalTray` | `Quickshell.Services.SystemTray` + `Quickshell.DBusMenu` | Menu rendering is manual |
| `AstalBattery` | `Quickshell.Services.UPower` | None |
| `AstalAuth` | `Quickshell.Services.Pam` | None |
| `Gtk4SessionLock` | `Quickshell.Wayland` (`WlSessionLock`) | None |
| `AstalBluetooth` | `Quickshell.Bluetooth` | Pairing agent and OBEX not in the module list; verify |
| `AstalNetwork` + `gi://NM` | `Quickshell.Networking` | Secret agent, VPN auth, EAP and hotspot connection building not in the module list; verify |
| `gi://Secret` (libsecret) | none | Agent-owned secrets in the keyring |
| `ags/process`, `ags/time` | `Quickshell.Io` (`Process`, `Socket`), `Timer` | None |

### What needs code outside QML (from reading the source)

Not a gap (a `Process` or module call covers it):

- `bluetooth/rfkill.ts`: runs `rfkill -J` and `rfkill event`. Pure `Process`.
- `bluetooth/services.ts`: connect and low-battery notifications, plus a `systemd-inhibit`-style subprocess held while a game controller is connected. All doable from QML with device signals, the notification server and `Process`.
- `Clipboard.tsx`: shells out to `cliphist` and `wl-copy`. Pure `Process`.
- `Keyboard.tsx`: listens to the Hyprland `keyboard-layout` event.

Real gaps (D-Bus or libnm objects with no Quickshell counterpart that I could confirm):

- `bluetooth/agent.ts` (150 lines): BlueZ `Agent1` for pairing PIN, passkey and confirmation prompts.
- `bluetooth/obex.ts` (249 lines): registers an `org.bluez.obex.Agent1` that accepts incoming files into `~/Downloads`, and also sends files (`ObjectPush1.SendFile`, transfer progress, cancel). Both directions.
- `network/agent.ts` (409 lines), `keyring.ts`: NetworkManager secret agent backed by libsecret.
- `network/vpn.ts`: drives the VPN plugin's own auth-dialog binary over its stdin/stdout protocol. It uses libnm only to find the dialog path and read the connection's VPN settings.
- `network/connections.ts` (388 lines): builds libnm connection objects for Wi-Fi (WPA, 802.1X EAP variants) and hotspots, and activates them.
- `network/model.ts`, `util.ts` (558 lines), `services.ts`: libnm-based state and helpers.

Counting the whole `bar/items/bluetooth` and `bar/items/network` `.ts` set (2,972 lines), roughly 1,900 lines depend on D-Bus or libnm. This is an estimate, not measured per function.

## 3. Decision needed: how to cover the gaps

| Option | What it means | Trade-off |
| --- | --- | --- |
| A. Sidecar daemons (recommended) | Move the agents into small standalone processes written in Python or Rust (or Go) using a D-Bus library. They talk to QML over a Unix socket using `Quickshell.Io.Socket`, or over `Process` with line-delimited JSON. | A rewrite of about 1,900 lines of D-Bus and libnm code, though the logic can be ported function by function. Keeps the Quickshell side pure QML and drops GTK and AGS. Adds two systemd units. |
| A-gjs. Sidecars in GJS | Same as A, but reuse the existing TS agent code. | Needs `gjs`, GTK-free GI libraries (libnm, libsecret) and a TS bundler (`esbuild`; `ags bundle` goes away). Close to option C in practice, so decide knowingly. |
| B. Pure QML plus `nmcli`/`bluetoothctl` | Shell out for connect, join and VPN. Drop the custom agents. | Smallest. Loses in-bar pairing dialogs and agent-owned Wi-Fi secrets. Behaviour change. |
| C. Keep AGS only for agents | Run a headless AGS process for the agents; Quickshell does all UI. | Fastest start. Keeps the AGS and GTK dependency, so the migration is not finished. |

Recommendation: A for the agents, with the sidecars exposing state and prompts as JSON so the QML dialogs stay thin. If rewriting is too much, A-gjs is the cheaper path. This is your decision; confirm before phase 5.

## 4. Target layout

```
flakes/components/
  default.nix            # quickshell build, two outputs kept: default, lock
  shell/
    shell.qml            # entry for the bar shell (replaces app.tsx)
    Config.qml           # singleton, port of bar/config.ts
    State.qml            # singleton, port of bar/state.ts
    Theme.qml            # singleton, colours/radii/fonts extracted from style.scss
    bar/                 # Bar.qml, items/*.qml
    widgets/             # DatePanel, Media, Notification, NotificationPopups, ScreenCorners
    bluetooth/ network/  # QML panels and dialogs
  lock/
    shell.qml            # entry for the lock screen
    Background.qml LockSurface.qml LoginBox.qml BottomBar.qml Clock.qml
  agents/                # sidecars from option A (only if chosen)
```

`bar/style.scss` (983 lines) and `lock/style.scss` (204 lines) do not port mechanically. QML has no cascading CSS. Extract the design tokens into `Theme.qml` first, then style each component from those tokens.

## 5. Phases

Each phase ends with something that runs. The new Quickshell outputs are built under new names (`qs-shell`, `qs-lock`) next to the AGS outputs (`default`, `lock`), which stay live and wired into Hyprland, hypridle and the `ags-bar` unit until phase 8. Nothing the system runs changes before phase 8, except for an optional test unit.

### Phase 0: Spike and decisions
- Get a v0.3.x Quickshell build (flake input or nixpkgs) into a scratch dev shell.
- Run `qs` against a trivial `PanelWindow` under Hyprland. Confirm layer-shell, autohide input-region behaviour, and per-monitor `Variants`.
- Check the pinned version's `Quickshell.Networking` and `Quickshell.Bluetooth` APIs against section 2.
- Pick option A, B or C from section 3.
- Exit: the table in section 2 is verified and the option is chosen.

### Phase 1: Packaging
- Add the `quickshell` input to `flake.nix` (follow our `nixpkgs`) and pass it to `./flakes/components` next to `ags` (around lines 18 and 79-81). `flake.nix` does change in this phase.
- Extend `default.nix` with new outputs `qs-shell` and `qs-lock`; leave `default` and `lock` untouched. Keep the `lockWallpaper` argument.
- The new outputs install wrappers (`my-shell`, `lock-screen`) that run `qs -p <store path>` with `QML_IMPORT_PATH` and the font config (`lockFonts`, Orbitron) set. Keep `LOCK_WALLPAPER` as `--set-default` and keep `LOCK_PREVIEW`.
- Dev shell: add `qs`, `qmlls`, `qmlformat`, and a `.qmlls.ini`, next to the AGS shell.
- Test the new outputs by running `nix run .#qs-shell` by hand, or through a separate, not-enabled test unit. Do not point `agsbar.nix` or the `lock` variable in `hyprland.nix` and `hypridle.nix` at them yet.
- Exit: `nix build .#qs-shell .#qs-lock` succeeds with placeholder QML, and the running desktop is unchanged.

### Phase 2: Foundations
- `Config.qml` from `bar/config.ts` (position, size, autohide, modules, worldClocks, taskbarIcons). Keep the same field names so config edits carry over.
- `State.qml` from `bar/state.ts` (`panelOpen`).
- `Theme.qml` from `style.scss` and `bar/style.scss`.
- `shell.qml` with `Variants { model: Quickshell.screens }` for bar and screen corners; single-instance overlays on the primary screen.
- Exit: empty bar renders on every monitor, reserves space (or autohides) per config.

### Phase 3: Simple bar items
Port in this order, smallest first: `Logo`, `Settings`, `Clock`, `Battery`, `Keyboard`, `Volume`, `Workspaces` (Hyprland plus icon lookup via `taskbarIcons`), `Systray`, `Clipboard`.
- Autohide: port `setupAutohide`. What the AGS code does today, and so what QML must reproduce:
  - Starts shown (a surface first mapped collapsed gets a bogus size from Hyprland), then starts the hide countdown once mapped.
  - While hidden, only a `revealZone` px strip at the screen edge takes input (cairo input region); while shown, the whole bar does. In QML this is the window `mask` (`Region`).
  - The window keeps full bar height while hidden; only the revealed content slides.
  - The bar stays up while the pointer is over it, `panelOpen` is true, or any popover is open. GTK polls the widget tree for open `Popover`s every 150 ms; QML must track its own `PopupWindow`s and panels in `State.qml` instead.
  - Opening the date panel (for example from a keybind) reveals the bar.
  This is the most fragile part; test on Hyprland early (phase 0 spike).
- `ScreenCorners` is an overlay window per monitor with an empty input region; use a `Canvas` or `Shape` for the concave corners.
- Exit: bar matches today's bar minus network, Bluetooth, date panel and notifications.

### Phase 4: Notifications, date panel, media
- `NotificationServer` replaces `AstalNotifd`. Port `Notification`, `NotificationPopups`, and the notification list inside `DatePanel`.
- Port `DatePanel` (world clocks, calendar) and `Media` (MPRIS).
- Danger: two notification daemons cannot own `org.freedesktop.Notifications`. Stop `ags-bar` before testing, or test on a nested session.
- Exit: notifications show, history works, date panel opens from the clock.

### Phase 5: Bluetooth
- UI first against `Quickshell.Bluetooth`: `AdapterSection`, `DeviceRow`, `index` panel.
- Then the gap code per the chosen option: pairing agent and `PairingDialog`, OBEX receive, rfkill watch, auto-connect and controller wakelock (`services.ts`), audio profile handling (`audio.ts`).
- Exit: pair, connect, trust, forget, send and receive a file, toggle rfkill.

### Phase 6: Network
- UI: `index`, `WifiSection`, `OtherSections`, `NetRow`, `InfoPanel`, `JoinDialog`, `SecretsDialog`.
- Gap code per the chosen option: NetworkManager secret agent (`agent.ts`, `keyring.ts`), VPN (`vpn.ts`), connection model (`model.ts`, `connections.ts`), connection notifications (`services.ts`). `util.ts` (558 lines) is mostly pure logic and should move verbatim to wherever the logic lives.
- Exit: join open, WPA and 802.1X networks; VPN toggle; secrets saved and prompted correctly.

### Phase 7: Lock screen

Process contract of today's `lock-screen`, which the QML version must keep (hypridle and the Hyprland binds depend on it):
- `hypridle` runs it as `lock_cmd` and via `loginctl lock-session` (and `before_sleep_cmd`). `inhibit_sleep = 3` holds suspend until the lock surface is up, per the comment in `hypridle.nix`. The process must therefore lock quickly and stay alive for the whole locked period.
- `hyprland.nix` binds also run `${lock}` directly (lines 308 and 313; the second runs `${lock} & sleep 1;` and then DPMS off).
- Single instance: AGS uses `instanceName = "lock"`. A second launch while one runs must not lock twice. Use Quickshell's no-duplicate option (verify the exact flag) or a lock file.
- If the compositor refuses the lock (another locker running), print an error and exit non-zero.
- If the protocol is unsupported, print an error and exit.
- On successful unlock: fade out windows for 260 ms, unlock, and only then exit. The AGS code documents the race: quitting before the unlock request has been sent makes the compositor report "lockscreen died". In QML, quit only after `WlSessionLock.locked` has become false (use `Qt.callLater`).
- Monitors plugged in while locked get a lock surface too (`WlSessionLockSurface` per screen in a `Variants` does this).
- If the process dies while locked, Hyprland's failsafe shows, and `allow_session_lock_restore = true` lets a new instance take over. Keep that setting.

Work:
- `WlSessionLock` with one `WlSessionLockSurface` per screen; `Pam` for auth with `PAM_SERVICE = "swaylock"`.
- Background: video loop, muted, with the idle pause (`IDLE_PAUSE_SECONDS`). Use Qt Multimedia `MediaPlayer` and `VideoOutput`, or run `mpvpaper`-style decoding in a child process. Check VA-API hardware decode and CPU use against the current GStreamer setup; this is the main risk for this phase.
- Port `LoginBox`, `BottomBar` (session name, Restart, Shut down with click-twice), `Clock`, fail-shake and caps-lock indicator, the `leaving` fade-out.
- Keep `LOCK_PREVIEW=1` (plain overlay windows, Escape quits) so the design can be worked on without locking.
- Keep `allow_session_lock_restore = true` in `hyprland.nix`; it is the safety net if the lock process dies.
- Exit: lock, fail a password, unlock, suspend and resume, kill the process while locked and relaunch it, launch it twice, and check there is no "lockscreen died" message after unlock. Test through hypridle's `loginctl lock-session` path as well as the keybind.

### Phase 8: Cutover and cleanup
- Flip the names: make `default` and `lock` point at the Quickshell builds (or repoint `agsbar.nix`, `hyprland.nix` and `hypridle.nix` at `qs-shell` and `qs-lock`) in one commit, so rollback is a single revert.
- Rename `shared/desktop/hypr/agsbar.nix` to `shell.nix` and the unit `ags-bar` to `quickshell-bar`. Update the import in `hyprland.nix`.
- Rename the `ags-shell` and `ags-lock` entries in `flake.nix` (lines 166-167), and drop the `ags` input and its `inputs.ags` pass-through (lines 18 and 81).
- Delete `app.tsx`, `env.d.ts`, `tsconfig.json`, `lock/tsconfig.json`, all `.tsx`, `.ts` and `.scss`, the `.envrc` if it only loads the AGS dev shell, and update `.gitignore`.
- Rewrite `README.md` (it still describes AGS and `ags run`) and delete this file.
- Exit: `nix flake check` passes, a fresh login starts the bar, and `grep -ri ags` finds nothing relevant.

## 6. Risks

1. **Agents** (section 3) are the largest unknown and the largest chunk of code.
2. **Lock video wallpaper**: Qt Multimedia backend choice, hardware decode and idle CPU may regress. Have a fallback of a static image.
3. **Autohide**: input-region and sizing behaviour differs between GTK layer-shell and Quickshell. Spike in phase 0.
4. **Locking yourself out**: test the lock screen only with `LOCK_PREVIEW=1` first, then with a TTY open (`pkill -f lock-screen`), as the README already advises.
5. **Notification daemon clash** during side-by-side testing (phase 4).
6. **Quickshell API churn**: pin the flake input and update deliberately.
7. **Styling effort**: the 1,212 lines of SCSS become QML property bindings; budget real time for this, not just logic porting.

## 7. Rollback

Until phase 8, the AGS outputs stay in the flake and the Hyprland, hypridle and `ags-bar` wiring still points at them, so nothing needs rolling back. After phase 8, rollback is `git revert` of the cutover commit.

## 8. Verification checklist (per phase)

- `nix build .#default .#lock` succeeds.
- `qs` logs show no QML warnings; `qmllint` is clean.
- Behaviour checked on: single monitor and multi-monitor, autohide on and off, top and bottom `position`.
- Lock: success, failure, suspend and resume, process killed while locked.
- `journalctl --user -u quickshell-bar` is clean after 10 minutes of use.
