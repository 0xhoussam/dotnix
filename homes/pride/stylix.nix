{ inputs, config, pkgs, lib, zenbones, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;

  # One still image for the palette tooling and any wallpaper-aware target:
  # a frame of the live wallpaper video (the video itself stays on mpvpaper).
  wallpaperFrame = pkgs.runCommand "misty-valley-frame.png" {
    nativeBuildInputs = [ pkgs.ffmpeg-headless ];
  } ''
    ffmpeg -loglevel error -ss 5 -i ${../../assets/wallpapers/misty-valley.mp4} -frames:v 1 $out
  '';

  sfPro = {
    package = inputs.apple-fonts.packages.${system}.sf-pro-nerd;
    name = "SFProDisplay Nerd Font";
  };
in
{
  stylix = {
    enable = true;
    # Only the targets listed below are themed; everything else keeps its own config.
    autoEnable = false;

    image = wallpaperFrame;
    polarity = "dark";

    # A fixed palette: libadwaita's dark colours with the GNOME accent set, so
    # the desktop keeps the look it has today. (Not generated from the image.)
    base16Scheme = {
      scheme = "Adwaita Dark";
      author = "local";
      base00 = "242424"; # window background
      base01 = "2d2d2d"; # popovers, raised surfaces
      base02 = "3d3d3d"; # selection
      base03 = "5e5c64"; # comments, muted
      base04 = "9a9996"; # dim text
      base05 = "deddda"; # text
      base06 = "f6f5f4";
      base07 = "ffffff";
      base08 = "ff7b63"; # red
      base09 = "ffa348"; # orange
      base0A = "f8e45c"; # yellow
      base0B = "8ff0a4"; # green
      base0C = "93ddc2"; # cyan
      base0D = "62a0ea"; # blue (accent)
      base0E = "dc8add"; # purple
      base0F = "cdab8f"; # brown
    };

    fonts = {
      sansSerif = sfPro;
      serif = sfPro;
      monospace = {
        package = zenbones.packages.${system}.zenbones-proto;
        name = "Zenbones Proto";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 17;
      };
    };

    targets = {
      gtk.enable = true;
      qt.enable = true;
      fontconfig.enable = true;
      mpv.enable = true;

      # Terminals keep their own colour themes (carbonfox in ghostty and kitty,
      # libadwaita in zellij, the terminal's palette for bat/fzf/fish), so the
      # Stylix colours stay out of them. Ghostty still gets the theme fonts.
      ghostty.enable = true;
      ghostty.colors.enable = false;
      # not enabled: kitty, alacritty, zellij, fish, bat, fzf
    };
  };

  # The shared modules (also used by other users, who do not have Stylix) set
  # these themselves; here Stylix wins.

  # The Quickshell shell reads this (flakes/components/shell/Theme.qml) and
  # follows the palette; `home-manager switch` recolours it live.
  xdg.configFile."my-shell/stylix.json".text = builtins.toJSON {
    polarity = config.stylix.polarity;
    font.sans = config.stylix.fonts.sansSerif.name;
    colors = lib.genAttrs (map (n: "base0${n}") [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" "F" ])
      (name: config.lib.stylix.colors.${name});
  };
}
