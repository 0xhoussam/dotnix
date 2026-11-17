{
  config,
  lib,
  pkgs,
  ...
}:
{

  imports = [
    ./../../shared/home-manager
    ./../../shared/desktop/hyprland
    ./../../shared/desktop/shell
    ./fonts.nix
    ./pkgs.nix
    ./xdg.nix
    ./theme.nix
    ./stylix.nix
    ./env.nix
    ./ssh.nix
    ./nix.nix
    ./zen.nix
    ./firefox.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home.username = "pride";
  home.homeDirectory = "/home/pride";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;

  # environment.variables.EDITOR = "nvim";
  home.stateVersion = "26.05";
}
