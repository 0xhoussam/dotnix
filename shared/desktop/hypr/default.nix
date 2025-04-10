{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./wofi.nix
    ./swww.nix
    ./anyrun.nix
    inputs.hyprcursor-phinger.homeManagerModules.hyprcursor-phinger
  ];

  home.packages = [
    inputs.hyprcursor.packages."${pkgs.system}".default
    pkgs.cliphist
  ];
  programs.hyprcursor-phinger.enable = true;

  services.cliphist.enable = true;
}
