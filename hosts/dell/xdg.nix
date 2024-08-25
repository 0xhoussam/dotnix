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

    config = {
      common = {
        default = [ "gnome" ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gnome"
          "gtk"
        ];
      };
    };
  };
}
