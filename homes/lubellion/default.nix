{ pkgs, ... }:
{

  imports = [
    ./../../shared/home-manager
    ./fonts.nix
    ./env.nix
    ./ssh.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home.username = "lubellion";
  home.homeDirectory = "/home/lubellion";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.packages = with pkgs; [
    code-cursor
  ];

  programs.home-manager.enable = true;

  home.stateVersion = "26.05";
}
