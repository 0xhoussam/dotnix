{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./neovim.nix
    ./sh.nix
    ./zellij.nix
  ];

  home.packages = with pkgs; [
    gcc
    nil
    nixfmt-rfc-style
    rustup
    go
  ];

  programs = {
    # batter shell history
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
