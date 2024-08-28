{ pkgs, ... }:
{
  services.printing.enable = true;
  services.gvfs.enable = true; # for nautilus
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
      };
    };
  };
}
