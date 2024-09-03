{ pkgs, ... }:
{
  services.printing.enable = true;
  services.gvfs.enable = true;
  # services.greetd = {
  #   enable = true;
  #   settings = {
  #     default_session = {
  #       command = "${pkgs.hyprland}/bin/Hyprland";
  #     };
  #   };
  # };
}
