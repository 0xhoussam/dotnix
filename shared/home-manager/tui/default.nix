{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./neovim.nix
  ];

  home.packages = with pkgs; [
    gcc
    nil
    nixfmt-rfc-style
    rustup
  ];
}
