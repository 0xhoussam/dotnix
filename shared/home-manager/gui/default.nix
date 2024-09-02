{ pkgs, ... }:
{
  imports = [
    ./alacritty.nix
    ./flatpak.nix
    ./vscode.nix
  ];

  home.packages = with pkgs; [ neovide ];
}
