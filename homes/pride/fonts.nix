{ pkgs, inputs, ... }:
{
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [
          "SFProDisplay Nerd Font"
        "IBM Plex Serif"
        "IBM Plex Sans Arabic"
      ];
      sansSerif = [
          "SFProDisplay Nerd Font"
        "Adwaita Sans"
        "IBM Plex Sans"
        "IBM Plex Sans Arabic"
      ];
      monospace = [ "Adwaita Mono" ];
    };
  };
  home.packages = with pkgs; [
    ibm-plex
    sf-mono-liga-bin
    nerd-fonts.zed-mono
    nerd-fonts.jetbrains-mono
    adwaita-fonts
    input-fonts
    inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd
    martian-mono
    lato
  ];
  nixpkgs.config.input-fonts.acceptLicense = true;
}
