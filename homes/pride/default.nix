{ ... }:
{

  imports = [
    ./../../shared/home-manager/gui
    ./../../shared/home-manager/tui
    ./../../shared/desktop/hypr
    ./fonts.nix
    ./pkgs.nix
    ./xdg.nix
    ./theme.nix
    ./env.nix
    ./ssh.nix
    # ./service.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home.username = "pride";
  home.homeDirectory = "/home/pride";

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];

  # environment.variables.EDITOR = "nvim";
  home.stateVersion = "24.11";
}
