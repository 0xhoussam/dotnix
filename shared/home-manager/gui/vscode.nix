{ pkgs, ... }:
let
  fleet-theme = pkgs.callPackage ./vscode-extensions/Jetbrains-fleettheme.nix { };
  jetbrains-icon-theme = pkgs.callPackage ./vscode-extensions/jetbrains-icon-theme.nix { };
in
{
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs; [
      vscode-extensions.vscodevim.vim
      jetbrains-icon-theme
      fleet-theme
    ];
  };
}
