{
  config,
  pkgs,
  lib,
  ...
}:
{

  imports = [
    ./../../shared/home-manager/gui
    ./../../shared/home-manager/tui
    ./../../shared/desktop/hypr
    ./fonts.nix
    ./pkgs.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home.username = "pride";
  home.homeDirectory = "/home/pride";

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";

  services.flatpak.packages = [ "org.gnome.Calculator" ];
}
