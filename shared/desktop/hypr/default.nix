{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./mako.nix
    ./waybar.nix
    ./wofi.nix
    ./walker.nix
    ./swww.nix
    inputs.hyprcursor-phinger.homeManagerModules.hyprcursor-phinger
  ];

  home.packages = [
    inputs.hyprcursor.packages."${pkgs.system}".default
  ];
  programs.hyprcursor-phinger.enable = true;
}
