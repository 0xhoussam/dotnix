{ pkgs, ... }:
{
  home.packages = with pkgs; [ font-awesome ];

  programs.waybar.enable = true;
  programs.waybar.settings = {
    mainBar = {
      height = 35;
      spacing = 4;
      modules-left = [
        "custom/logo"
        "hyprland/workspaces"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "cpu"
        "backlight"
        "pulseaudio"
        "tray"
      ];
      tray = {
        spacing = 16;
      };
      clock = {
        format = "{:%d %b   %H:%M}";
        tooltip = false;
      };
      pulseaudio = {
        format = "{volume}% {icon}";
        format-bluetooth = "{volume}% {icon}";
        format-muted = "";
        format-icons = {
          headphone = "";
          hands-free = "";
          headset = "";
          phone = "";
          portable = "";
          car = "";
          default = [
            ""
            ""
          ];
        };
        scroll-step = 1;
        on-click = "pavucontrol";
        ignored-sinks = [ "Easy Effects Sink" ];
      };
      backlight = {
        device = "intel_backlight";
        format = "{percent}%  {icon}";
        format-icons = [ "" ];
      };
      "hyprland/workspaces" = {
        format = "{name}";
        on-click = "activate";
      };
      cpu = {
        format = "{usage}% ";
        tooltip = false;
        on-click = "flatpak run net.nokyan.Resources";
      };

      "custom/logo" = {
        format = "󱄅";
        tooltip = false;
      };

    };
  };

  programs.waybar.style = # css
    ''
            * {
        font-family:
          IBM Plex Sans Condensed,
          FontAwesome,
          Noto Sans,
          sans-serif;
        font-size: 14px;
      }

      window#waybar {
        background-color: #1e1e1e;
        color: #f4f4f4;
        transition-property: background-color;
        transition-duration: 0.5s;
      }

      window#waybar.hidden {
        opacity: 0.2;
      }

      #workspaces {
        margin: 0;
        padding: 0;
        background-color: #383838;
        margin: 4px 0;
        border-radius: 10px;
      }

      #workspaces button.active {
        background-color: #3584e4;
        color: #f4f4f4;
        border-radius: 10px;
      }

      /* If workspaces is the leftmost module, omit left margin */
      .modules-left > widget:first-child > #workspaces {
        margin-left: 0;
      }

      .modules-right {
        background-color: #383838;
        border-radius: 10px;
        margin: 4px 0;
        padding: 0px 10px;
      }

      /* If workspaces is the rightmost module, omit right margin */
      .modules-right > widget:last-child > #workspaces {
        margin-right: 0;
      }

      @keyframes blink {
        to {
          background-color: #ffffff;
          color: #000000;
        }
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #c01c28;
      }

      #clock {
        padding-right: 10px;
        margin-right: 10px;
        font-weight: bold;
      }

      #pulseaudio {
        padding-right: 10px;
        margin-right: 10px;
      }

      #backlight {
        padding-right: 10px;
        margin-right: 10px;
      }

      #cpu {
        padding-right: 10px;
        margin-right: 10px;
      }

      #custom-logo {
        font-size: 25px;
        margin-right: 25px;
        padding-left: 10px;
      }

      #tray {
        padding-right: 5px;
      }
    '';
}