{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./neovim.nix
    ./sh.nix
    ./zellij.nix
  ];

  home.packages = with pkgs; [ nixfmt-rfc-style ];

  programs = {
    # batter shell history
    atuin = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
