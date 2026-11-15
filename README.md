# dotnix

A not overly engineered Nix flake for my machine and my sanity. Take what you like.

## Layout

| Path | What |
| ---- | ---- |
| `hosts/bystial` | NixOS configuration of the laptop. |
| `homes/pride` | Home Manager configuration (standalone). |
| `shared/` | Modules shared by the host and the home, such as the Hyprland desktop. |
| `flakes/components` | The desktop shell: Quickshell bar and lock screen plus a Rust D-Bus sidecar. See its README. |
| `flakes/eshot`, `flakes/zenbones-mono-flake` | Small local packages. |
| `docs/` | Design notes and plans. |
| `assets/` | Wallpapers. |

## Hardware

| Hostname  | CPU / GPU | OS  |
| --------- | --------- | --- |
| `bystial` | see `hosts/bystial/hardware-configuration.nix` | NixOS |

## Usage

```sh
sudo nixos-rebuild switch --flake .#bystial
home-manager switch --flake .#pride
nix run .#qs-shell        # try the shell without switching (from flakes/components)
```

## Software

System config lives in Nix modules; user config in Home Manager. A few things
are not ported (Neovim, for one).

- Terminal: Alacritty, with Zellij
- Shell: zsh
- Editor: Neovim
- Desktop: Hyprland with a custom Quickshell shell
- Browser: Zen
- Theming: Stylix
- Dev environments: Devenv + Direnv
