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
    ./../../shared/home-manager/desktop
    ./fonts.nix
    ./pkgs.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home.username = "pride";
  home.homeDirectory = "/home/pride";

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
