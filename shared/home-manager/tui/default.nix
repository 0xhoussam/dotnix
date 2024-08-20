{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./neovim.nix
    ./sh.nix
  ];

  home.packages = with pkgs; [
    gcc
    nil
    nixfmt-rfc-style
    rustup
    go
  ];
}
