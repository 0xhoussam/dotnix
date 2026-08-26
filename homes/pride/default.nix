{
  config,
  lib,
  pkgs,
  ...
}:
{

  imports = [
    ./../../shared/home-manager
    ./../../shared/desktop/hypr
    ./fonts.nix
    ./pkgs.nix
    ./xdg.nix
    ./theme.nix
    ./env.nix
    ./ssh.nix
    ./nix.nix
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
