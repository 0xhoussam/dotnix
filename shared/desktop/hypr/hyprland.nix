{ inputs, pkgs, ... }:
let
  ghostty = "${pkgs.ghostty}/bin/ghostty";
  swayosd-client = "${pkgs.swayosd}/bin/swayosd-client";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
  swww = "${pkgs.swww}/bin/swww";
  background = ../../../assets/wallpapers/tanjiro.jpg;
  tmp = inputs.vicinae.packages.${pkgs.system}.default;
  vicinae = "${tmp}/bin/vicinae";
in
{
  imports = [
    ./hyprlock.nix
    ./hypridle.nix
    ./env.nix
    ./service.nix
    ./swaync.nix
  ];
  home.packages = [
    pkgs.playerctl
    pkgs.hyprshot
    pkgs.brightnessctl
    pkgs.swww
  ];

  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.systemd.variables = [ "--all" ];
  wayland.windowManager.hyprland.extraConfig = ''
    env = HYPRCURSOR_THEME,McMojave
    env = HYPRCURSOR_SIZE,24
  '';
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";

    monitor = [
      "eDP-1,preferred, auto, 1, bitdepth, 8"
      "HDMI-A-1,1920x1080@100,1920x0,1"
    ];

    workspace = [
      "3,monitor:HDMI-A-1"
    ];

    input = {
      kb_layout = "us,us,ara";
      kb_variant = "dvorak,,";
      kb_options = "grp:win_space_toggle";
      follow_mouse = 1;
      touchpad = {
        natural_scroll = true;
        clickfinger_behavior = true;
      };
    };

    cursor = {
      hide_on_key_press = true;
    };

    animation = [
      "windows, 1, 6, default, slide"
    ];

    device = {
      name = "elan-touchscreen";
      enabled = false;
    };

    decoration = {
      rounding = 15;
      blur = {
        enabled = true;
        size = 3;
        passes = 1;
        new_optimizations = "on";
        vibrancy = 0.1696;
      };

      shadow = {
        enabled = false;
      };
    };

    ecosystem = {
      no_update_news = true;
    };

    gesture = [
      "3, horizontal, workspace"
    ];

    master.new_status = true;
    bind = [
      "$mod, Return, exec, ${ghostty}"
      "$mod, b, exec, flatpak run app.zen_browser.zen "
      "$mod, e, exec, xdg-open $HOME"
      "$mod, W, killactive,"
      "$mod, M, exit,"
      "$mod, V, togglefloating,"
      "$mod, R, exec, ${vicinae} toggle"
      "$mod, F, fullscreen"

      "$mod SHIFT, h, cyclenext"

      "$mod, h, movefocus, l"
      "$mod, l, movefocus, r"
      "$mod, j, movefocus, u"
      "$mod, k, movefocus, d"

      "$mod, 1, workspace, 1"
      "$mod, 2, workspace, 2"
      "$mod, 3, workspace, 3"
      "$mod, 4, workspace, 4"
      "$mod, 5, workspace, 5"
      "$mod, 6, workspace, 6"
      "$mod, 7, workspace, 7"
      "$mod, 8, workspace, 8"
      "$mod, 9, workspace, 9"
      "$mod, 0, workspace, 10"

      "$mod SHIFT, 1, movetoworkspace, 1"
      "$mod SHIFT, 2, movetoworkspace, 2"
      "$mod SHIFT, 3, movetoworkspace, 3"
      "$mod SHIFT, 4, movetoworkspace, 4"
      "$mod SHIFT, 5, movetoworkspace, 5"
      "$mod SHIFT, 6, movetoworkspace, 6"
      "$mod SHIFT, 7, movetoworkspace, 7"
      "$mod SHIFT, 8, movetoworkspace, 8"
      "$mod SHIFT, 9, movetoworkspace, 9"
      "$mod SHIFT, 0, movetoworkspace, 10"

      "$mod, mouse_down, workspace, e+1"
      "$mod, mouse_up, workspace, e-1"

      "$mod CTRL, L, exec, ${hyprlock}"
      "$mod SHIFT CTRL, L, exec, ${hyprlock} && ${hyprctl} dispatch dpms off"

      "$mod CTRL, P, exec, ${hyprshot} -m window"
      "$mod SHIFT, P, exec, ${hyprshot} -m region"
    ];

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];

    bindl = [
      ", XF86MonBrightnessUp, exec, ${swayosd-client} --brightness raise"
      ", XF86MonBrightnessDown, exec, ${swayosd-client} --brightness lower"
      ", XF86AudioRaiseVolume, exec,  ${swayosd-client} --output-volume raise"
      ", XF86AudioLowerVolume, exec, ${swayosd-client} --output-volume lower"
      ", XF86AudioMute, exec, ${swayosd-client} --output-volume mute-toggle"
      ", XF86AudioPlay, exec, ${playerctl} play-pause"
      ", XF86AudioPrev, exec, ${playerctl} previous"
      ", XF86AudioNext, exec, ${playerctl} next"
    ];

    windowrulev2 = [
      "float,title:^(Calculator)"
      "float,class:^(xdg-desktop-portal-gtk)"
      "float,class:^(blueman-manager)"
      "float,class:^(pavucontrol)"
      "float,class:^(nm-connection-editor)"
      "float,class:^(xdg-desktop-portal)"
      "float,class:^(xdg-desktop-portal-gnome)"
      "float,class:^(de.haeckerfelix.Fragments)"
      "float,class:^(pavucontrol)"
    ];

    misc = {
      mouse_move_enables_dpms = true;
      key_press_enables_dpms = true;
      focus_on_activate = true;
    };

    general = {
      allow_tearing = true;
      gaps_in = 2;
      gaps_out = 3;
      border_size = 2;
      "col.active_border" = "0xff1c71d8";
      "col.inactive_border" = "0";

      layout = "dwindle";
    };

    layerrule = [
      "blur, waybar"
      "blur,vicinae"
      "ignorealpha 0, vicinae"
    ];

    exec-once = [
      "${swww} img --transition-type wipe --transition-angle 30 --transition-step 90 ${background}"
      "${vicinae} server"
    ];
  };
}
