{ pkgs, ... }:
{
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [
        "IBM Plex Serif"
        "IBM Plex Sans Arabic"
      ];
      sansSerif = [
        "IBM Plex Sans"
        "IBM Plex Sans Arabic"
      ];
      monospace = [ "ZedMono Nerd Font" ];
    };
  };
  home.packages = with pkgs; [
    ibm-plex
    julia-mono
    (nerdfonts.override {
      fonts = [
        "ZedMono"
        "JetBrainsMono"
      ];
    })
  ];
}
