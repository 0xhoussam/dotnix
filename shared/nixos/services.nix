{ pkgs, ... }:
{
  services = {
    # devmon.enable = true;
    # gnome.gnome-keyring.enable = true;
    libinput.enable = true;
    earlyoom.enable = true; # Trigger oom early before systems becomes unusable
    dbus.packages = [ pkgs.gcr ];
    openssh.enable = true;
    xserver = {
      xkb.layout = "us,ar";
      xkb.variant = "dvorak,";
      xkb.options = "grp:win_space_toggle";
    };
  };
  console.keyMap = "us";

  systemd.coredump.enable = true;
}
