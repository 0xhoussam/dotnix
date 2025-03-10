{ pkgs, ... }:
let
  font = "ZedMono Nerd Font";
  shell = "${pkgs.zsh}/bin/zsh";
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      general = {
        live_config_reload = true;
      };
      colors = rec {
        cursor = {
          text = "#292929";
          cursor = "#52a7f6";
        };
        primary = {
          background = "#181818";
          foreground = "#d1d1d1";
        };
        bright = {
          black = "#000000";
          red = "#CC7C8A";
          green = "#afcb85";
          yellow = "#e5c995";
          blue = "#52a7f6";
          magenta = "#a390f0";
          cyan = "#78d0bd";
          white = "#d6d6dd";
        };
        normal = bright;
        selection = {
          text = "#292929";
          background = "#767676";
        };
      };
      env = {
        TERM = "xterm-256color";
      };
      font = {
        size = 12;
        normal = {
          family = "${font}";
          style = "Regular";
        };
        italic = {
          family = "${font}";
          style = "Italic";
        };
        bold = {
          family = "${font}";
          style = "Bold";
        };
        bold_italic = {
          family = "${font}";
          style = "Bolditalic";
        };
      };
      terminal = {
        shell = {
          args = [ "--login" ];
          program = "${shell}";
        };
      };
      window = {
        opacity = 1;
        startup_mode = "Windowed";
        title = "Alacritty";
        decorations = "None";
        padding = {
          x = 10;
          y = 1;
        };
      };
      keyboard = {
        bindings = [
          {
            key = "F11";
            action = "ToggleFullscreen";
          }
        ];
      };
    };
  };
}
