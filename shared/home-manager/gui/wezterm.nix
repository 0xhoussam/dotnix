{ pkgs, inputs, ... }:
{
  programs.wezterm = {
    enable = true;
    package = inputs.wezterm.packages.${pkgs.system}.default;
    extraConfig = # lua
      ''
        local config = wezterm.config_builder()
        config.font = wezterm.font 'ZedMono Nerd Font'
        config.window_decorations = "NONE"
        config.colors = {
            background = "#181818";
            foreground = "#ffffff";
            cursor_fg = "#52a7f6";
            ansi = {
                '#1e1e1e',
                '#CC7C8A',
                '#afcb85',
                '#A8CC7C',
                '#7dbeff',
                '#a390f0',
                '#00AF99',
                '#6d6d6d',
            }
             brights = {
                '#535353',
                '#CC7C8A',
                '#A8CC7C',
                '#e5c995',
                '#52a7f6',
                '#a390f0',
                '#78d0bd',
                '#ffffff',
              },
        }
        config.enable_tab_bar = false;
        return config
      '';
    colorSchemes = {
      fleet = {
        ansi = [
          "#181818"
          "#CC7C8A"
          "#afcb85"
          "#efb080"
          "#e5c995"
          "#a390f0"
          "#78d0bd"
          "#d6d6dd"
        ];
        background = "#181818";
        brights = [
          "#1e1e1e"
          "#E44C7A"
          "#afcb85"
          "#DEA407"
          "#a390f0"
          "#d898d8"
          "#7dbeff"
          "#ffffff"
        ];
        compose_cursor = "#efb080";
        cursor_bg = "#afcb85";
        cursor_border = "#2197F3";
        cursor_fg = "#181818";
        foreground = "#d6d6dd";
        scrollbar_thumb = "#afcb85";
        selection_bg = "#1F3661";
        selection_fg = "rgba(255, 255, 255 0)";
        split = "#a390f0";
      };
      adwaita = {
        ansi = [
          "#2E3440"
          "#BF616A"
          "#A3BE8C"
          "#EBCB8B"
          "#88C0D0"
          "#B48EAD"
          "#81A1C1"
          "#D8DEE9"
        ];
        background = "#2E3440";
        brights = [
          "#4C566A"
          "#BF616A"
          "#A3BE8C"
          "#EBCB8B"
          "#88C0D0"
          "#B48EAD"
          "#81A1C1"
          "#FFFFFF"
        ];
      };
    };
  };
}
