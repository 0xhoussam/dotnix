{ pkgs, ... }:
{
  fonts.fontconfig.enable = true;
  home.packages = with pkgs; [
    ibm-plex
    (nerdfonts.override { fonts = [ "ZedMono" ]; })
  ];
}
