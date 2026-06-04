{ inputs, pkgs, ... }:
let
  ghostty = "${pkgs.ghostty}/bin/ghostty";
  swayosd-client = "${pkgs.swayosd}/bin/swayosd-client";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
  awww = "${pkgs.awww}/bin/awww";
  background = ../../../assets/wallpapers/tanjiro.jpg;
  # AGS bar (separate flake under ~/projects/components). nix run rebuilds the
  # bundle if its source changed, so dev edits land on next login.
  bar = "${pkgs.nix}/bin/nix run path:/home/pride/projects/components";
  vicinae = "${inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/vicinae";

  workspaceBinds = builtins.concatLists (
    builtins.genList (
      i:
      let
        ws = toString (i + 1);
        key = if i == 9 then "0" else ws;
      in
      [
        "$mod, ${key}, workspace, ${ws}"
        "$mod SHIFT, ${key}, movetoworkspace, ${ws}"
      ]
    ) 10
  );
in
{
  imports = [
    ./hyprlock.nix
    ./hypridle.nix
    ./env.nix
    ./service.nix
  ];
  home.packages = [
    pkgs.playerctl
    pkgs.hyprshot
    pkgs.brightnessctl
    pkgs.awww
  ];

  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.configType = "hyprlang";
  wayland.windowManager.hyprland.systemd.variables = [ "--all" ];
  wayland.windowManager.hyprland.systemd.enableXdgAutostart = true;
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";

    monitor = [
      "eDP-1,preferred, auto, 1, bitdepth, 8"
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

    device = [
      {
        name = "elan-touchscreen";
        enabled = false;
      }
    ];

    gesture = [
      "3, horizontal, workspace"
    ];

    general = {
      allow_tearing = true;
      gaps_in = 2;
      gaps_out = 3;
      border_size = 2;
      "col.active_border" = "0xff1c71d8";
      "col.inactive_border" = "0";

      layout = "dwindle";
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

    animation = [
      "windows, 1, 6, default, popin"
    ];

    misc = {
      mouse_move_enables_dpms = true;
      key_press_enables_dpms = true;
      focus_on_activate = true;
      disable_hyprland_logo = true;
    };

    ecosystem = {
      no_update_news = true;
    };

    master.new_status = "master";

    binds = {
      movefocus_cycles_fullscreen = true;
    };

    # windowrulev2 = [
    #   "float, class:^(org.gnome.Calculator)$"
    #   "float, class:^(C)$"
    #   "float, class:^(xdg-desktop-portal-gtk)$"
    #   "float, class:^(blueman-manager)$"
    #   "float, class:^(pavucontrol)$"
    #   "float, class:^(nm-connection-editor)$"
    #   "float, class:^(xdg-desktop-portal)$"
    #   "float, class:^(de.haeckerfelix.Fragments)$"
    # ];

    # layerrule = [
    #   "blur, ^(waybar)$"
    #   # "blur, ^(vicinae)$"
    #   # "ignorealpha 0, ^(vicinae)$"
    # ];

    bind = [
      "$mod, Return, exec, ${ghostty}"
      "$mod, b, exec, flatpak run app.zen_browser.zen"
      "$mod, e, exec, xdg-open $HOME"
      "$mod, W, killactive,"
      "$mod, M, exit,"
      "$mod, V, togglefloating,"
      "$mod, R, exec, ${vicinae} toggle"
      "$mod, F, fullscreen"
      "$mod, Tab, workspace, previous"

      "$mod, h, movefocus, l"
      "$mod, l, movefocus, r"
      "$mod, j, movefocus, u"
      "$mod, k, movefocus, d"

      "$mod, mouse_down, workspace, e+1"
      "$mod, mouse_up, workspace, e-1"

      "$mod CTRL, L, exec, ${hyprlock}"
      "$mod SHIFT CTRL, L, exec, ${hyprlock} && ${hyprctl} dispatch dpms off"

      "$mod CTRL, P, exec, ${hyprshot} -m window"
      "$mod SHIFT, P, exec, ${hyprshot} -m region"
      ", Print, exec, ${hyprshot} -m region --clipboard-only"
    ]
    ++ workspaceBinds;

    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];

    bindel = [
      ", XF86MonBrightnessUp, exec, ${swayosd-client} --brightness raise"
      ", XF86MonBrightnessDown, exec, ${swayosd-client} --brightness lower"
      ", XF86AudioRaiseVolume, exec, ${swayosd-client} --output-volume raise"
      ", XF86AudioLowerVolume, exec, ${swayosd-client} --output-volume lower"
    ];

    bindl = [
      ", XF86AudioMute, exec, ${swayosd-client} --output-volume mute-toggle"
      ", XF86AudioPlay, exec, ${playerctl} play-pause"
      ", XF86AudioPrev, exec, ${playerctl} previous"
      ", XF86AudioNext, exec, ${playerctl} next"
    ];

    exec-once = [
      "${awww} img --transition-type wipe --transition-angle 30 --transition-step 90 ${background}"
      bar
      # "${vicinae} server"
    ];
  };
}
