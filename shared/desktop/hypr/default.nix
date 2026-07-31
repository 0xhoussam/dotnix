{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./wofi.nix
    ./awww.nix
  ];

  home.packages = [
    pkgs.cliphist
  ];

  services.cliphist.enable = true;
}
