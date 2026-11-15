# Plan: adopt Stylix

Status: proposal. Nothing has been changed yet.

Stylix (https://nix-community.github.io/stylix/) is a theming framework for NixOS and Home Manager: one palette, wallpaper, font set and cursor, applied to every supported program. This plan covers adding it to this repo and wiring it to the Quickshell shell.

## 1. What I checked

From the Stylix documentation (installation and configuration pages; the per-target module list returned 404, so the exact list of supported targets is NOT verified):

- `master` is rolling. All inputs must be updated together. This repo already tracks `nixos-unstable` and Home Manager `master`, which is the matching pairing.
- The flake input is `stylix.url = "github:nix-community/stylix"` with `inputs.nixpkgs.follows = "nixpkgs"`. Modules: `stylix.nixosModules.stylix` and `stylix.homeModules.stylix`.
- Nothing is themed until `stylix.enable = true`. The main options are `stylix.image` (wallpaper; the palette is generated from it unless a scheme is given), `stylix.base16Scheme`, `stylix.polarity` (`dark` or `light`), `stylix.fonts` (serif, sans-serif, monospace, emoji), `stylix.override`, `stylix.targets.<name>.enable`, and `stylix.autoEnable`.
- If Home Manager runs as a NixOS module, the NixOS theme flows into it. If the two are configured separately, the theme has to be set in both.

From this repo:

- Home Manager is **standalone**: `homeConfigurations.pride` and `homeConfigurations.lubellion`. The NixOS hosts (`bystial`, `dell`) are separate, so the Home Manager side is the natural place to start.
- Current theming is hand-made and scattered: GTK `adw-gtk3` with Numix icons and SF Pro font plus dark preference (`homes/pride/theme.nix`); Qt through Kvantum with `KvLibadwaitaDark`; a fixed Hyprland border colour `0xff1c71d8`; Ghostty font "Zenbones Proto"; separate colour settings in kitty, alacritty, zellij, fish, zsh, bat (`base16`), delta, anyrun, waybar and wofi; cursor `McMojave`; `dconf` colour scheme.
- The wallpaper is a **video** (`misty-valley.mp4` through `mpvpaper`). Stylix needs an image, so a still frame has to be produced.
- Hyprland's config is a hand-written **Lua** file, not `settings` through Home Manager. Stylix's Hyprland integration most likely does not apply to it (unverified), so Hyprland colours will need to be taken from the palette by hand.
- The Quickshell shell has its own `Theme.qml` with dark and light modes and six accent colours (`theme.json`). The lock screen has a separate dark HUD with a fixed cyan.
- `homeConfigurations.lubellion` already fails to evaluate for an unrelated reason (`zenbones` missing in `homes/lubellion/fonts.nix`). It is not caused by this work, but it blocks verifying that user.

## 2. Decisions needed before building

1. **Palette source:** generate it from a wallpaper image, or use a fixed base16 scheme? A fixed scheme (for example an Adwaita-like dark one) keeps the current libadwaita look and is predictable. A generated one follows the wallpaper but can look different after every wallpaper change.
2. **Wallpaper image:** a frame extracted from `misty-valley.mp4` at build time (`ffmpeg` derivation, no new asset), or a dedicated still image?
3. **Polarity:** dark only, or follow a switch?
4. **Fonts:** which package for sans-serif (SF Pro Nerd today), monospace (Zenbones Proto in Ghostty, or the system one), and emoji.
5. **Scope:** Home Manager only (simplest), or also the NixOS module (console colours; the `tuigreet` login screen is probably not themed)?
6. **Users:** `pride` only, or also `lubellion` (shared modules would need it too)?
7. **Qt:** keep `kvlibadwaita` or let Stylix generate the Kvantum theme? They conflict.

## 3. Phases

Work happens on a branch. Nothing goes live until `home-manager switch`, and each phase ends with a rebuild that can be reverted.

### Phase 0: spike
- Add the `stylix` input (following `nixpkgs`) and import `stylix.homeModules.stylix` in `homes/pride`.
- Set `stylix.enable = true`, `stylix.autoEnable = false`, an image and a scheme. Build the activation package only (`nix build .#homeConfigurations.pride.activationPackage`). Confirm evaluation is clean and look at the generated palette (`config.lib.stylix.colors`).
- Exit: builds with every target off.

### Phase 1: inputs for the theme
- Add a derivation that extracts one frame from the wallpaper video (if decision 2 says so).
- Settle scheme, polarity and fonts (decisions 1, 3, 4). Put them in one `shared/home-manager/stylix.nix`.
- Exit: one file defines the whole theme.

### Phase 2: enable targets one at a time
Enable each target separately and check it before the next, resolving option conflicts with the existing config:
1. Fonts and cursor (replace the `gtk.font` and cursor settings).
2. GTK (keep `adw-gtk3`, let Stylix's colours override it), then Qt (decision 7).
3. Terminals and shells: kitty, ghostty, alacritty, zellij, fish, bat, delta (drop the hard-coded colours where Stylix now provides them).
4. Anyrun, browsers (Zen profile names are needed), mpv, btop, editors.
- Disable targets that clash: any wallpaper target (the live wallpaper stays on `mpvpaper`) and the Hyprland target if it does not apply to the Lua config.
- Exit: each enabled target looks right in a running session.

### Phase 3: Hyprland
- Take the border colours (and any other colours) from `config.lib.stylix.colors` and write them into the Lua string in `shared/desktop/hypr/hyprland.nix`, replacing `0xff1c71d8`.
- Exit: borders follow the scheme.

### Phase 4: Quickshell bridge
- A Home Manager `xdg.configFile` writes `~/.config/my-shell/stylix.json` with the base16 colours, polarity and font names from `config.lib.stylix`.
- `Theme.qml` gets a "system" source: when `stylix.json` exists it maps the palette to the existing tokens (background from base00/base01, text from base05, accent from base0D, danger base08, warn base0A) and takes dark or light from the polarity. The manual dark/light and accent choices in Quick Settings stay as the fallback when the file is absent. The file is watched, so `home-manager switch` recolours the running shell.
- Fonts: the shell follows the fontconfig default sans-serif, which Stylix sets.
- Lock screen: optionally tint the HUD cyan from the palette; the Orbitron font stays.
- Exit: switching the Stylix scheme changes the bar, panels and OSD without a restart.

### Phase 5: NixOS module (only if decision 5 says so)
- Import `stylix.nixosModules.stylix` for the hosts and check what changes (console colours, boot).

### Phase 6: verification and rollout
- Build both Home Manager configs (`lubellion` is blocked by its existing `zenbones` error until that is fixed).
- `home-manager switch` on one machine, go through the apps, take screenshots, and keep the previous generation for rollback (`home-manager generations`, or `git revert` plus a switch).

## 4. Risks

1. Stylix `master` moves; a partial `nix flake update` can break it. Update every input together.
2. Targets and existing programs both set colours and fonts; expect option conflicts that need `lib.mkForce` or removing the old setting.
3. A palette generated from the wallpaper can change look with every wallpaper change; a fixed scheme avoids that.
4. Electron apps and Brave are not themed by Stylix. Apps with their own themes (Zen, Cursor, VS Code) need the right profile or target options.
5. The hand-written Lua Hyprland config and the Kvantum setup are the two places most likely to need manual work.
6. Quickshell has no known Stylix target (unverified), so the bridge in phase 4 is custom and has to be kept in step with `Theme.qml`.

## 5. Open questions for you

The seven decisions in section 2. The two that change the most: fixed scheme or generated from the wallpaper, and Home Manager only or also NixOS.
