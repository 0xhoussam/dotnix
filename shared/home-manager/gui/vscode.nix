{ pkgs, ... }:
let
  fleet-theme = pkgs.callPackage ./vscode-extensions/Jetbrains-fleettheme.nix { };
in
{
  programs.vscode = {
    enable = true;
    extensions = with pkgs; [
      vscode-extensions.vscodevim.vim
      fleet-theme
    ];
    userSettings = {
      "window.titleBarStyle" = "custom";
      "editor.fontSize" = 18;
      "editor.fontFamily" = "monospace";
    };
  };
}
