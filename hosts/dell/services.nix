{ pkgs, ... }:
{
  services.printing.enable = true;
  services.gvfs.enable = true;
  services.flatpak.enable = true;
}
