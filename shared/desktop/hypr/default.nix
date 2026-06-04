{ inputs, pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./wofi.nix
    ./vicinie.nix
    ./awww.nix
  ];

  home.packages = [
    pkgs.cliphist
  ];

  services.cliphist.enable = true;
}
