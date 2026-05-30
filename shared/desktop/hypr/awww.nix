{ pkgs, ... }:
{
  home.packages = with pkgs; [ awww ];
  systemd.user.services.awww = {
    Unit = {
      Description = "Wallpaper daemon";
      Documentation = [ "man:awww-daemon(1)" ];

      Requires = [ "hyprland-session.target" ];
    };
    Service = {
      Type = "notify";

      Environment = "XDG_RUNTIME_DIR=/run/user/%U";
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
