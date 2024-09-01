{ pkgs, ... }:
{
  xdg.terminal-exec.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gnome
    ];
    xdgOpenUsePortal = true;
    config = {
      common = {
        default = [
          "hyprland"
          "gnome"
        ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gnome"
        ];
      };
    };
  };
}
