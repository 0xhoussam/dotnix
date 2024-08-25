{ ... }:
{

  imports = [
    ./../../shared/home-manager/gui
    ./../../shared/home-manager/tui
    ./../../shared/desktop/hypr
    ./fonts.nix
    ./pkgs.nix
    ./vscode.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home.username = "pride";
  home.homeDirectory = "/home/pride";

  programs.home-manager.enable = true;

  # environment.variables.EDITOR = "nvim";
  home.stateVersion = "24.11";
}
