{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./wofi.nix
    ./awww.nix
    ./hyprsunset.nix
    ./sherlock.nix
  ];

  home.packages = [
    pkgs.cliphist
  ];

  services.cliphist.enable = true;
}
