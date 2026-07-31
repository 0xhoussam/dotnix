{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  zenbones = inputs.zenbones.packages.${pkgs.stdenv.hostPlatform.system};
in
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
    inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
    zenbones.zenbones-proto
    geist-font
  ];
  nixpkgs.config.input-fonts.acceptLicense = true;
  home.activation.linkFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.local/share/fonts"
    find ${config.home.profileDirectory}/share/fonts -type f \( -iname "*.ttf" -o -iname "*.otf" \) \
      -exec ln -sf {} "$HOME/.local/share/fonts/" \;
    ${pkgs.fontconfig}/bin/fc-cache -f "$HOME/.local/share/fonts"
  '';
}
