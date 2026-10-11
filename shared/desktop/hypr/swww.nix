{ pkgs, ... }:
{
  home.packages = with pkgs; [ swww ];
  systemd.user.services.swww = {
    Unit = {
      Description = "Wallpaper daemon";
      Documentation = [ "man:swww-daemon(1)" ];

      Requires = [ "hyprland-session.target" ];
    };
    Service = {
      Type = "notify";

      Environment = "XDG_RUNTIME_DIR=/run/user/%U";
      ExecStart = "${pkgs.swww}/bin/swww-daemon";
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
