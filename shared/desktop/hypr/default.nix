{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./wofi.nix
    ./swww.nix
    ./anyrun.nix
  ];

  home.packages = [
    pkgs.cliphist
  ];

  services.cliphist.enable = true;
}
