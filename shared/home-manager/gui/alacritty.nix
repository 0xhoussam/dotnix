{ pkgs, ... }:
let
  font = "ZedMono Nerd Font";
  shell = "${pkgs.zsh}/bin/zsh";
  corbonfox_theme_path = ".config/alacritty/theme/corbonfox.toml";
  fleet_theme_path = ".config/alacritty/theme/fleet.toml";
in
{
  programs.alacritty = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "alacritty";
      paths = [ pkgs.alacritty ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/alacritty \
          --set DRI_PRIME 1
      '';
    };
    settings = {
      general = {
        live_config_reload = true;
        import = [ "theme/corbonfox.toml" ];
      };
      env = {
        TERM = "xterm-256color";
      };
      font = {
        size = 12;
        normal = {
          family = "${font}";
          style = "Semibold";
        };
        italic = {
          family = "${font}";
          style = "Semibolditalic";
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

  home.file."${corbonfox_theme_path}" = {
    enable = true;
    text = # toml
      ''
        [colors.primary]
        background = "#161616"
        foreground = "#f2f4f8"
        dim_foreground = "#b6b8bb"
        bright_foreground = "#f9fbff"

        [colors.cursor]
        text = "#f2f4f8"
        cursor = "#b6b8bb"

        [colors.vi_mode_cursor]
        text = "#f2f4f8"
        cursor = "#33b1ff"

        [colors.search.matches]
        foreground = "#f2f4f8"
        background = "#525253"

        [colors.search.focused_match]
        foreground = "#f2f4f8"
        background = "#3ddbd9"

        [colors.footer_bar]
        foreground = "#f2f4f8"
        background = "#353535"

        [colors.hints.start]
        foreground = "#f2f4f8"
        background = "#3ddbd9"

        [colors.hints.end]
        foreground = "#f2f4f8"
        background = "#353535"

        [colors.selection]
        text = "#f2f4f8"
        background = "#2a2a2a"

        [colors.normal]
        black = "#282828"
        red = "#ee5396"
        green = "#25be6a"
        yellow = "#08bdba"
        blue = "#78a9ff"
        magenta = "#be95ff"
        cyan = "#33b1ff"
        white = "#dfdfe0"

        [colors.bright]
        black = "#484848"
        red = "#f16da6"
        green = "#46c880"
        yellow = "#2dc7c4"
        blue = "#8cb6ff"
        magenta = "#c8a5ff"
        cyan = "#52bdff"
        white = "#e4e4e5"

        [colors.dim]
        black = "#222222"
        red = "#ca4780"
        green = "#1fa25a"
        yellow = "#07a19e"
        blue = "#6690d9"
        magenta = "#a27fd9"
        cyan = "#2b96d9"
        white = "#bebebe"

      '';
  };

  home.file."${fleet_theme_path}" = {
    enable = true;
    text = # toml
      ''
        [cursor]
        text = "#292929"
        cursor = "#52a7f6"

        [primary]
        background = "#181818"
        foreground = "#d1d1d1"

        [bright]
        black = "#000000"
        red = "#CC7C8A"
        green = "#afcb85"
        yellow = "#e5c995"
        blue = "#52a7f6"
        magenta = "#a390f0"
        cyan = "#78d0bd"
        white = "#d6d6dd"

        [normal]
        black = "#000000"
        red = "#CC7C8A"
        green = "#afcb85"
        yellow = "#e5c995"
        blue = "#52a7f6"
        magenta = "#a390f0"
        cyan = "#78d0bd"
        white = "#d6d6dd"

        [selection]
        text = "#292929"
        background = "#767676"

      '';
  };
}
