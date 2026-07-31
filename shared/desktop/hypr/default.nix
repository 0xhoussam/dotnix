{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./wofi.nix
    ./awww.nix
    ./hyprsunset.nix
  ];

  home.packages = [
    pkgs.cliphist
  ];

  services.cliphist.enable = true;
}
