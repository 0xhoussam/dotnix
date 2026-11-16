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

    # A fixed palette, not generated from the image: Carbonfox, the same
    # theme the terminal uses (ghostty, shared/home-manager/gui/ghostty.nix).
    # This is the one place the desktop's colours are defined: GTK, Qt, mpv,
    # the Hyprland border, the Quickshell bar and the lock screen (both read
    # ~/.config/my-shell/stylix.json, generated below) and zellij follow it.
    # Carbonfox has no real yellow or orange (its "yellow" is teal), so those
    # two slots use IBM Carbon's own, to keep warnings readable.
    base16Scheme = {
      scheme = "Carbonfox";
      author = "EdenEast/nightfox.nvim, IBM Carbon";
      base00 = "161616"; # window background
      base01 = "252525"; # popovers, raised surfaces
      base02 = "2a2a2a"; # selection
      base03 = "7b7c7e"; # comments, muted
      base04 = "a9afbc"; # dim text
      base05 = "f2f4f8"; # text
      base06 = "f2f4f8";
      base07 = "ffffff";
      base08 = "ee5396"; # red
      base09 = "ff832b"; # orange (Carbon)
      base0A = "f1c21b"; # yellow (Carbon)
      base0B = "25be6a"; # green
      base0C = "33b1ff"; # cyan
      base0D = "78a9ff"; # blue (accent)
      base0E = "be95ff"; # purple
      base0F = "ff7eb6"; # pink
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

      # Terminals keep their own colour theme (carbonfox in ghostty and kitty,
      # the terminal's palette for bat/fzf/fish): it is the same theme as the
      # scheme above, and the terminal palette has 16 hand-tuned colours.
      # Ghostty still gets the theme fonts.
      ghostty.enable = true;
      ghostty.colors.enable = false;
      zellij.enable = true;
      # not enabled: kitty, alacritty, fish, bat, fzf
    };
  };

  # The shared modules (also used by other users, who do not have Stylix) set
  # these themselves; here Stylix wins.

  # The Quickshell shell reads this (pkgs/desktop-shell/shell/Theme.qml) and
  # follows the palette; `home-manager switch` recolours it live.
  xdg.configFile."my-shell/stylix.json".text = builtins.toJSON {
    polarity = config.stylix.polarity;
    font.sans = config.stylix.fonts.sansSerif.name;
    colors = lib.genAttrs (map (n: "base0${n}") [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" "F" ])
      (name: config.lib.stylix.colors.${name});
  };
}
