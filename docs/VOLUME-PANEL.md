# Plan: volume dropdown for the bar

Status: implemented (all phases, with your answers: left click opens the panel, middle click mutes the microphone, everything including the volume overlay and microphone dot, 150% as an option, Bluetooth audio fix included). Built and rendered; the slider drag, device switching, per-app sliders, overlay and Bluetooth profile switching are untested with real interaction.

## 1. Where we are

`shell/bar/items/Volume.qml` is a bar pill showing the default output's icon and percentage. Click toggles mute, scroll changes the volume in 5% steps. It has no dropdown. The AGS version had none either, so this is a new feature, not a port.

## 2. What to include (research summary)

Compared with the sound panels in GNOME quick settings, KDE Plasma's volume popup, and common Hyprland bar setups, the useful and expected pieces are, in priority order:

1. **Output volume**: a slider with a mute button and the percentage. This is the core of the panel.
2. **Output device picker**: a list of sinks (speakers, HDMI, headphones, Bluetooth) with the default one marked. Clicking one makes it the default.
3. **Input volume**: a slider with a mute button for the default microphone, plus an input device picker.
4. **Per-application volume**: one row per playing application (browser, player, game) with its own slider and mute. Recording applications go in the input section.
5. **Sound Settings button**: opens `pavucontrol` for anything the panel does not cover. `pavucontrol` is installed on this machine; `pwvucontrol` is not.

Worth adding after that, lower priority:

6. **Level meter** on the output and microphone sliders, so the user can see that sound is actually flowing.
7. **Volume OSD**: a small overlay shown when the volume changes from a keybind or scroll, then fading. Common in GNOME and KDE.
8. **Microphone-in-use dot** on the bar when an application is recording (a privacy indicator).
9. **Over-amplification** up to 150% behind an option, off by default.

Deliberately left out: media controls (the date panel already has them), per-channel balance, equalizer, and card profile switching for non-Bluetooth devices. They add clutter and none of the references put them in the quick panel.

## 3. Data sources (verified)

Everything the panel needs is in `Quickshell.Services.Pipewire`. I checked the type list in the installed package (`quickshell-service-pipewire.qmltypes`, v0.3.2), not the web docs, which were not reachable.

| Need | API |
| --- | --- |
| Default output / input | `Pipewire.defaultAudioSink`, `Pipewire.defaultAudioSource` |
| Change the default | assign `Pipewire.preferredDefaultAudioSink` / `preferredDefaultAudioSource` |
| All devices and streams | `Pipewire.nodes` (filter on `isSink`, `isStream` and `type` flags) |
| Volume and mute | `node.audio.volume`, `node.audio.muted` (per channel: `volumes`, `channels`) |
| Names | `node.description`, `node.nickname`, `node.properties` (map, for `application.name`, `application.icon-name`, `media.name`) |
| Level meter | `PwNodePeakMonitor` (`peak`, `peaks`, `enabled`) |
| Which app feeds which sink | `PwNodeLinkTracker`, `Pipewire.links` |
| Keep nodes bound | `PwObjectTracker { objects: [...] }`, required before reading `audio` |

No sidecar work is needed. The exact values of the `type` flags are not shown in the type list, so phase 2 must check them against the live node list.

## 4. Layout

```
┌──────────────────────────────┐
│ Sound                     ⚙  │   ⚙ = Sound Settings (pavucontrol)
├──────────────────────────────┤
│ Output                       │
│ 🔊 ━━━━━━━━●━━━━━━━  35%  🔇 │   slider + mute
│ ▸ Speaker            ✓       │   device list (collapsed to the
│   HDMI / DisplayPort 1       │   current one, expands on click)
├──────────────────────────────┤
│ Input                        │
│ 🎤 ━━━━━━━━━━━━●━━━  89%  🔇 │
│ ▸ Digital Microphone  ✓      │
├──────────────────────────────┤
│ Applications                 │   only while something plays
│ [icon] Brave        ━━●━━ 🔇 │
│ [icon] Spotify      ━━━●━ 🔇 │
└──────────────────────────────┘
```

It follows the existing popup pattern (`PopupWindow` anchored under the pill, `HyprlandFocusGrab` to close on outside click, `Toggle`, `Chip`, `ListRow`, `Tint` icons). The slider is a new shared widget (`widgets/Slider.qml`), since there is none yet.

## 5. Phases

Each phase builds and runs on its own.

### Phase 1: panel shell and output volume
- Turn `Volume.qml` into a `Pill` with a `PopupWindow`, like the Bluetooth and network items.
- Add `widgets/Slider.qml`: drag, click to jump, scroll, and a fill that uses the accent color.
- Output section: slider, mute button, percentage, same icon logic as the pill.
- Keep scroll-on-pill on the bar item; the click gestures depend on open question 1.
- Exit: slider and pill stay in sync both ways, mute works, outside click closes.

### Phase 2: device pickers
- Output and input device lists from `Pipewire.nodes`, filtered to hardware sinks and sources (no streams, no monitor sources).
- Click sets `preferredDefaultAudioSink` / `Source`; the check mark follows the real default.
- Nice names: prefer `nickname`, fall back to `description`.
- Exit: switching output moves a playing stream to the new device.

### Phase 3: input and per-application volume
- Input slider and mute for the default source.
- Applications section: playback streams with icon (from `application.icon-name`, falling back to the generic audio icon), name, slider, mute. Hide the section when empty.
- Recording streams listed under Input.
- Exit: changing an app slider changes only that app.

### Phase 4: polish
- Level meter via `PwNodePeakMonitor`, enabled only while the popup is open.
- Sound Settings button (`pavucontrol`).
- Optional 150% limit in a small options row.
- Middle-click on the pill mutes the microphone.

### Phase 5 (optional): OSD and mic dot
- Volume OSD overlay window on the primary screen, shown for about 1.2 s after a volume or mute change, click-through.
- Microphone-in-use dot on the bar.

## 6. Related finding: Bluetooth audio profiles are broken

While checking the audio tools I found `pactl` is not installed on this system. `shell/bluetooth/BtAudio.qml` (audio profile and default output/mic buttons in the device panel) shells out to `pactl`, so that section silently never appears. `wpctl` and `pw-dump` are installed, and `wpctl` has `set-profile ID INDEX` and `set-default ID`. The fix is to read cards and profiles from `pw-dump` and switch with `wpctl`. This is a small change and I suggest doing it alongside phase 2, since the device pickers reuse the same node data.

## 7. Risks

1. Reading `node.audio` before a `PwObjectTracker` binds the node gives null or stale values; every list row needs its node tracked.
2. Stream names are inconsistent (`application.name`, `media.name`, `node.name`); some apps need fallbacks.
3. Peak monitors cost CPU if left on, so they must be enabled only while the popup is visible.
4. Setting the default device through `preferred...` depends on WirePlumber honouring it; verify on this machine.
5. A slider that writes on every pointer move can flood PipeWire; throttle to roughly 30 writes per second.

## 8. Open questions for you

1. **Open gesture:** left click currently toggles mute. Should left click open the dropdown (and mute moves to the mute button inside it and to middle click), as in GNOME and KDE? Or keep mute on left click and open the dropdown on right click?
2. **Scope:** build phases 1 to 4, or also the OSD and mic dot (phase 5)?
3. **Maximum volume:** cap at 100%, or allow up to 150% behind an option?
4. **Bluetooth audio fix:** include it with phase 2 as proposed?
