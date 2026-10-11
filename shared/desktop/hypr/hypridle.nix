{ config, inputs, pkgs, components, ... }:
let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  lock = "${components.packages.${pkgs.stdenv.hostPlatform.system}.lock}/bin/lock-screen";
  loginctl = "${pkgs.systemd}/bin/loginctl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  # Hyprland's config is Lua now: `hyprctl dispatch` takes a Lua dispatcher.
  dpms = state: "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"${state}\" })'";
  # Only save + dim when not already dim: a second `-s` while dimmed (e.g.
  # hypridle restarted mid-dim) would overwrite the saved level with the dim
  # one, and `-r` would then "restore" to near-black.
  dimLevel = 10;
  dim = pkgs.writeShellScript "hypridle-dim" ''
    cur=$(${brightnessctl} -m | cut -d, -f3)
    [ "$cur" -gt ${toString dimLevel} ] && ${brightnessctl} -s set ${toString dimLevel}
    exit 0
  '';
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${lock}";
        before_sleep_cmd = "${loginctl} lock-session";
        after_sleep_cmd = dpms "on";
        ignore_dbus_inhibit = false;
        # hold suspend until the lock surface is actually up, so the desktop
        # never shows on resume (lock-session alone returns immediately)
        inhibit_sleep = 3;
      };

      listener = [
        {
          timeout = 150; # 2.5min.
          on-timeout = "${dim}";
          on-resume = "${brightnessctl} -r";
        }
        {
          timeout = 150; # 2.5min.
          on-timeout = "${brightnessctl} -sd tpacpi::kbd_backlight set 0"; # turn off keyboard backlight.
          on-resume = "${brightnessctl} -rd tpacpi::kbd_backlight"; # turn on keyboard backlight.
        }
        {
          timeout = 300; # 5min
          on-timeout = "${loginctl} lock-session"; # lock screen when timeout has passed
        }
        {
          timeout = 330; # 5.5min
          on-timeout = dpms "off"; # screen off when timeout has passed
          on-resume = dpms "on"; # screen on when activity is detected after timeout has fired.
        }
        {
          timeout = 420; # 7min
          on-timeout = "${systemctl} suspend"; # suspend pc
        }
      ];
    };
  };
}
