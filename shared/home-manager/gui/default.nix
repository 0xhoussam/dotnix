{ pkgs, ... }:
{
  imports = [
    ./alacritty.nix
    ./vscode.nix
  ];

  home.packages = with pkgs; [
    neovide
  ];
}
