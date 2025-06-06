{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./neovim.nix
    ./zsh.nix
    ./zellij.nix
    ./fish.nix
    ./bat.nix
  ];

  home.packages = with pkgs; [ nixfmt-rfc-style ];

  programs = {
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
