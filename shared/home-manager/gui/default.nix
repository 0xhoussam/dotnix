{ pkgs, ... }:
{
  imports = [
    ./alacritty.nix
    ./flatpak.nix
  ];

  home.packages = with pkgs; [ neovide ];
}
