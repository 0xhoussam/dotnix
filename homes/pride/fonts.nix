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
    ubuntu_font_family
    sf-mono-liga-bin
    victor-mono
    nerd-fonts.zed-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-cove
    nerd-fonts.fira-code
    nerd-fonts.inconsolata-go
    adwaita-fonts
    input-fonts
    nerd-fonts.iosevka
    inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd
    nerd-fonts.meslo-lg
  ];
  nixpkgs.config.input-fonts.acceptLicense = true;
}
