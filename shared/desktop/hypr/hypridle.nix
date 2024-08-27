{ pkgs, ... }:
let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
  loginctl = "${pkgs.systemd}/bin/loginctl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  systemctl = "${pkgs.systemd}/bin/systemctl";
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${hyprlock}";
        before_sleep_cmd = "${loginctl} lock-session";
        after_sleep_cmd = "${hyprctl} dispatch dpms on";
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          timeout = 150; # 2.5min.
          on-timeout = "${brightnessctl} -s set 10";
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
          on-timeout = "${hyprctl} dispatch dpms off"; # screen off when timeout has passed
          on-resume = "${hyprctl} dispatch dpms on"; # screen on when activity is detected after timeout has fired.
        }
        {
          timeout = 1800; # 30min
          on-timeout = "${systemctl} suspend"; # suspend pc
        }
      ];
    };
  };
}
