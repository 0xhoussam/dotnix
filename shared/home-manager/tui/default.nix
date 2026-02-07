{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./neovim.nix
    ./zsh.nix
    ./zellij.nix
    ./fish.nix
    ./bat.nix
    ./delta.nix
  ];

  programs = {
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
