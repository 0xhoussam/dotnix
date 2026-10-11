{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./wofi.nix
    ./mpvpaper.nix
    ./hyprsunset.nix
    ./sherlock.nix
  ];

  home.packages = [
    pkgs.cliphist
  ];

  services.cliphist.enable = true;
}
