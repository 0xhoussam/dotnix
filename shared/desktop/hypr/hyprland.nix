{
  inputs,
  pkgs,
  lib,
  self,
  config,
  components,
  ...
}:

let
  playerctl = lib.getExe pkgs.playerctl;
  lock = "${components.packages.${pkgs.stdenv.hostPlatform.system}.lock}/bin/lock-screen";
  hyprctl = lib.getExe pkgs.hyprland;
  hyprshot = lib.getExe pkgs.hyprshot;
  awww = lib.getExe pkgs.awww;
  background = "${self.outPath}/assets/wallpapers/tanjiro.jpg";
  kitty = lib.getExe pkgs.kitty;
  firefox = lib.getExe pkgs.firefox;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  wpctl = "${pkgs.wireplumber}/bin/wpctl";

  hyprlandLua = /* lua */ ''
            local mod = "SUPER"

            ---------------------------------------------------------------------------
            -- Monitors
            ---------------------------------------------------------------------------

            hl.monitor({
              output = "eDP-1",
              mode = "preferred",
              position = "auto",
              scale = 1,
              bitdepth = 8,
            })


            ---------------------------------------------------------------------------
            -- Input
            ---------------------------------------------------------------------------

            hl.config({
              input = {
                kb_layout = "us,us,ara",
                kb_variant = "dvorak,,",
                kb_options = "grp:win_space_toggle",

                follow_mouse = 1,

                touchpad = {
                  natural_scroll = true,
                  clickfinger_behavior = true,
                },
              },

              cursor = {
                hide_on_key_press = true,
              },
            })


            ---------------------------------------------------------------------------
            -- Devices
            ---------------------------------------------------------------------------

            hl.device({
              name = "elan-touchscreen",
              enabled = false,
            })


            ---------------------------------------------------------------------------
            -- Gestures
            ---------------------------------------------------------------------------

            hl.gesture({
              fingers = 3,
              direction = "horizontal",
              action = "workspace",
            })

            hl.gesture({
              fingers = 3,
              direction = "vertical",
              action = "workspace",
            })


            ---------------------------------------------------------------------------
            -- General
            ---------------------------------------------------------------------------

            hl.config({
              general = {
                allow_tearing = true,

                gaps_in = 2,
                gaps_out = 3,

                border_size = 2,

                ["col.active_border"] = "0xff1c71d8",
                ["col.inactive_border"] = "0",

                layout = "scrolling",
              },

              decoration = {
                rounding = 15,

                blur = {
                  enabled = false,
                },

                shadow = {
                  enabled = false,
                },
              },

              misc = {
                mouse_move_enables_dpms = true,
                key_press_enables_dpms = true,
                focus_on_activate = true,
                disable_hyprland_logo = true,
              },

              ecosystem = {
                no_update_news = true,
              },

              master = {
                new_status = "master",
              },

              binds = {
                movefocus_cycles_fullscreen = true,
              },
            })


            ---------------------------------------------------------------------------
            -- Animations
            ---------------------------------------------------------------------------

            hl.animation({
            leaf = "windows",
            enabled = true,
            speed = 6,
            bezier = "default",
            style = "popin",
            })


            ---------------------------------------------------------------------------
            -- Applications
            ---------------------------------------------------------------------------

            hl.bind(
              mod .. " + RETURN",
              hl.dsp.exec_cmd("${kitty}")
            )

            hl.bind(
              mod .. " + B",
              hl.dsp.exec_cmd("${firefox}")
            )

hl.bind(
              mod .. " + E",
              hl.dsp.exec_cmd("xdg-open $HOME")
            )


            hl.bind(
              mod .. " + R",
              hl.dsp.exec_cmd("anyrun")
            )


            ---------------------------------------------------------------------------
            -- Window management
            ---------------------------------------------------------------------------

            hl.bind(
              mod .. " + W",
              hl.dsp.window.close()
            )

            hl.bind(
              mod .. " + V",
              hl.dsp.window.float({ action = "toggle" })
            )

            hl.bind(
              mod .. " + F",
              hl.dsp.window.fullscreen()
            )

            hl.bind(
              mod .. " + M",
              hl.dsp.exit()
            )

            hl.bind(
              mod .. " + TAB",
              hl.dsp.focus({ workspace = "previous" })
            )


            ---------------------------------------------------------------------------
            -- Focus movement
            ---------------------------------------------------------------------------

        hl.bind(
            mod .. " + H",
            hl.dsp.focus({ direction = "l" })
        )

        hl.bind(
            mod .. " + L",
            hl.dsp.focus({ direction = "r" })
        )

        hl.bind(
            mod .. " + J",
            hl.dsp.focus({ direction = "u" })
        )

        hl.bind(
            mod .. " + K",
            hl.dsp.focus({ direction = "d" })
        )


            ---------------------------------------------------------------------------
            -- Workspace scrolling
            ---------------------------------------------------------------------------

        hl.bind(
            mod .. " + mouse_down",
            hl.dsp.focus({ workspace = "e+1" })
        )

        hl.bind(
            mod .. " + mouse_up",
            hl.dsp.focus({ workspace = "e-1" })
        )


            ---------------------------------------------------------------------------
            -- Workspaces 1-10
            ---------------------------------------------------------------------------

            local workspaces = {
              { key = "1", workspace = 1 },
              { key = "2", workspace = 2 },
              { key = "3", workspace = 3 },
              { key = "4", workspace = 4 },
              { key = "5", workspace = 5 },
              { key = "6", workspace = 6 },
              { key = "7", workspace = 7 },
              { key = "8", workspace = 8 },
              { key = "9", workspace = 9 },
              { key = "0", workspace = 10 },
            }

            for _, ws in ipairs(workspaces) do

                -- Switch to workspace
                hl.bind(
                    mod .. " + " .. ws.key,
                    hl.dsp.focus({ workspace = ws.workspace })
                )

                -- Move active window to workspace
                hl.bind(
                    mod .. " + SHIFT + " .. ws.key,
                    hl.dsp.window.move({ workspace = ws.workspace })
                )

            end


            ---------------------------------------------------------------------------
            -- Mouse window movement
            ---------------------------------------------------------------------------

            hl.bind(
          mod .. " + mouse:272",
          hl.dsp.window.drag(),
          { mouse = true }
        )

        hl.bind(
          mod .. " + mouse:273",
          hl.dsp.window.resize(),
          { mouse = true }
        )

            ---------------------------------------------------------------------------
            -- Lock screen
            ---------------------------------------------------------------------------

            hl.bind(
              mod .. " + CTRL + L",
              hl.dsp.exec_cmd("${lock}")
            )

            hl.bind(
              mod .. " + SHIFT + CTRL + L",
              hl.dsp.exec_cmd("${lock} && ${hyprctl} dispatch dpms off")
            )


            ---------------------------------------------------------------------------
            -- Screenshots
            ---------------------------------------------------------------------------

            hl.bind(
              mod .. " + CTRL + P",
              hl.dsp.exec_cmd("${hyprshot} -m window")
            )

            hl.bind(
              mod .. " + SHIFT + P",
              hl.dsp.exec_cmd("${hyprshot} -m region")
            )

            hl.bind(
              "Print",
              hl.dsp.exec_cmd("${hyprshot} -m region --clipboard-only")
            )


            ---------------------------------------------------------------------------
            -- Brightness
            ---------------------------------------------------------------------------

            hl.bind(
              "XF86MonBrightnessUp",
              hl.dsp.exec_cmd("${brightnessctl} set 10%+"),
              { repeating = true }
            )

            hl.bind(
              "XF86MonBrightnessDown",
              hl.dsp.exec_cmd("${brightnessctl} set 10%-"),
              { repeating = true }
            )


            ---------------------------------------------------------------------------
            -- Volume
            ---------------------------------------------------------------------------

            hl.bind(
              "XF86AudioRaiseVolume",
              hl.dsp.exec_cmd("${wpctl} set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
              { repeating = true }
            )

            hl.bind(
              "XF86AudioLowerVolume",
              hl.dsp.exec_cmd("${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
              { repeating = true }
            )

            hl.bind(
              "XF86AudioMute",
              hl.dsp.exec_cmd("${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"),
              { locked = true }
            )


            ---------------------------------------------------------------------------
            -- Media controls
            ---------------------------------------------------------------------------

            hl.bind(
              "XF86AudioPlay",
              hl.dsp.exec_cmd("${playerctl} play-pause"),
              { locked = true }
            )

            hl.bind(
              "XF86AudioPrev",
              hl.dsp.exec_cmd("${playerctl} previous"),
              { locked = true }
            )

            hl.bind(
              "XF86AudioNext",
              hl.dsp.exec_cmd("${playerctl} next"),
              { locked = true }
            )


            ---------------------------------------------------------------------------
            -- Startup
            ---------------------------------------------------------------------------

            hl.on("hyprland.start", function()
              hl.exec_cmd(
                "${awww} img --transition-type wipe --transition-angle 30 --transition-step 90 ${background}"
              )
            end)
  '';

in
{
  imports = [
    ./hypridle.nix
    ./env.nix
    ./service.nix
    ./agsbar.nix
    ./anyrun.nix
  ];

  home.packages = [
    pkgs.playerctl
    pkgs.hyprshot
    pkgs.brightnessctl
    pkgs.awww
    pkgs.wireplumber
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    # Hyprland >= 0.55 uses Lua.
    configType = "lua";

    systemd.variables = [ "--all" ];
    systemd.enableXdgAutostart = true;

    # IMPORTANT:
    # Do not use `settings` for this Lua configuration.
    #
    # Home Manager's Lua settings generation has had issues with
    # Hyprland's new Lua configuration format.
    extraConfig = hyprlandLua;
  };
}
