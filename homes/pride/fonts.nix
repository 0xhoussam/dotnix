{
  pkgs,
  inputs,
  lib,
  zenbones,
  ...
}:
let
  zenbonesPkgs = zenbones.packages.${pkgs.stdenv.hostPlatform.system};
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
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.iosevka
    nerd-fonts.commit-mono
    adwaita-fonts
    input-fonts
    inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd
    martian-mono
    lato
    cascadia-code
    zenbonesPkgs.zenbones-proto
    monaspace
    geist-font
  ];

  home.activation.linkFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.local/share/fonts"
    find -L "$HOME/.nix-profile/share/fonts" -type f \( -iname "*.ttf" -o -iname "*.otf" \) \
      -exec ln -sf {} "$HOME/.local/share/fonts/" \;
    $DRY_RUN_CMD ${pkgs.fontconfig}/bin/fc-cache -f "$HOME/.local/share/fonts"
  '';

  nixpkgs.config.input-fonts.acceptLicense = true;
}
