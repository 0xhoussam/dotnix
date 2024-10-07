{ pkgs, ... }:
let
  zjstatusPluginPath = "https://github.com/dj95/zjstatus/releases/download/v0.17.0/zjstatus.wasm";
in
{
  programs.zellij.enable = true;
  programs.zellij.settings = {
    simplified_ui = true;
    default_shell = "${pkgs.zsh}/bin/zsh";
    pane_frames = false;
    # auto_layout = false;
    copy_command = "wl-copy";
    theme = "libadwaita";
    themes.libadwaita = {
      fg = "#fafafa";
      bg = "#1e1e1e";
      black = "#242424";
      white = "#ffffff";
      red = "#e01b24";
      green = "#2ec27e";
      yellow = "#e5a50a";
      blue = "#3584e4";
      magenta = "#9141ac";
      cyan = "#78d0bd";
      orange = "#efb080";
    };
  };

  home.file.".config/zellij/layouts/default.kdl" = {
    text = ''
      layout {
        tab {
          pane split_direction="vertical"
        }

        swap_tiled_layout name="vertical" {
              tab max_panes=5 {
              pane split_direction="vertical" {
                  pane
                  pane { children; }
              }
          }
          tab max_panes=8 {
              pane split_direction="vertical" {
                  pane { children; }
                  pane { pane; pane; pane; pane; }
              }
          }
          tab max_panes=12 {
              pane split_direction="vertical" {
                  pane { children; }
                  pane { pane; pane; pane; pane; }
                  pane { pane; pane; pane; pane; }
              }
          }
        }

        swap_tiled_layout name="horizontal" {
              tab max_panes=5 {
              pane
              pane
          }
          tab max_panes=8 {
              pane {
                  pane split_direction="vertical" { children; }
                  pane split_direction="vertical" { pane; pane; pane; pane; }
              }
          }
          tab max_panes=12 {
              pane {
                  pane split_direction="vertical" { children; }
                  pane split_direction="vertical" { pane; pane; pane; pane; }
                  pane split_direction="vertical" { pane; pane; pane; pane; }
              }
          }
        }

        default_tab_template {
          children
          pane size=1 borderless=true {
              plugin location="${zjstatusPluginPath}" {
                  format_left  "#[fg=#2ec27e,bg=NONE,bold] {mode}  |  {tabs}"
                  format_right "#[fg=#fafafa,bg=NONE]{datetime}"
                  format_space "#[bg=NONE]"

                  mode_normal        "{name}"
                  mode_locked        "{name}"
                  mode_resize        "{name}"
                  mode_pane          "{name}"
                  mode_tab           "{name}"
                  mode_scroll        "{name}"
                  mode_enter_search  "{name}"
                  mode_search        "{name}"
                  mode_rename_tab    "{name}"
                  mode_rename_pane   "{name}"
                  mode_session       "{name}"
                  mode_move          "{name}"
                  mode_prompt        "{name}"
                  mode_tmux          "{name}"

                  hide_frame_for_single_pane "true"

                  tab_normal   "#[bg=NONE,fg=#fafafa]{index}:{name}"
                  tab_active   "#[bg=NONE,fg=#3584e4,bold]*{index}:[{name}]"

                  datetime          " {format} "
                  datetime_format   "%H:%M %d-%b-%y"
                  datetime_timezone "Africa/Casablanca"
              }
          }
        }
      }
    '';
  };
}
