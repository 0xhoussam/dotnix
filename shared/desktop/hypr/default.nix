{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./wofi.nix
    ./swww.nix
    ./vicinie.nix
  ];

  home.packages = [
    pkgs.cliphist
  ];

  services.cliphist.enable = true;
}
