# dotnix

This is my not overly engineerd nix flake for managing my machines and keeping my sanity.

Explore the reposity take what you like.

## Hardware


| Hostname | Brand                    | CPU             | RAM  | GPU                    | OS  |
| -------- | ------------------------ | --------------- | ---- | ---------------------- | --- |
| `project`| -_-                      |  Intel i7-5500U | 16Gb | AMD ATI Radeon R7 M265 | Nix |

## Sofware

System wide config is managed through nix and nix modules everything else is managed through home-manager. Some configurations still not yet ported to nix. (some of them will never like neovim).

- Terminal: [Weztem](https://github.com/wez/wezterm)
- Terminal multiplexer: [Zellij](https://github.com/zellij-org/zellij)
- Shell: zsh
- Editor: Neovim
- Desktop: Hyprland
- Browser: Zen
- Development environments: [Devenv](https://github.com/cachix/devenv) + [Direnv](https://github.com/nix-community/nix-direnv)

