{ pkgs, ... }:
let
  fleet-theme = pkgs.callPackage ./vscode-extensions/Jetbrains-fleettheme.nix { };
  jetbrains-icon-theme = pkgs.callPackage ./vscode-extensions/jetbrains-icon-theme.nix { };
in
{
  programs.vscode = {
    enable = true;
    extensions = with pkgs; [
      vscode-extensions.vscodevim.vim
      jetbrains-icon-theme
      fleet-theme
    ];
    userSettings = {
      "window.titleBarStyle" = "custom";
      "editor.fontSize" = 18;
      "editor.fontFamily" = "Liga SFMono Nerd Font";
      "workbench.colorTheme" = "Jetbrains Fleet";
      "editor.lineNumbers" = "relative";
      "workbench.list.smoothScrolling" = true;
      "editor.tabSize" = 4;
      "workbench.iconTheme" = "vscode-jetbrains-icon-theme-2023-dark";
    };
  };
}
