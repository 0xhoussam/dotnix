{ pkgs, ... }:
{
  xdg.terminal-exec.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    xdgOpenUsePortal = true;
    config = {
      common = {
        default = [
          "gtk"
          "hyprland"
        ];
      };
      hyprland = {
        default = [
          "gtk"
          "hyprland"
        ];
      };
    };
  };
}
