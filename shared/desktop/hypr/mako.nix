{ pkgs, ... }:
{
  services.mako = {
    enable = true;
    layer = "top";
    anchor = "bottom-right";
    font = "Adwaita Sans";
    backgroundColor = "#242424";
    textColor = "#fafafa";

    width = 350;
    margin = "10,30,30";
    padding = "10";
    borderSize = 2;
    borderColor = "#3584e4";
    progressColor = "over #262626ff";
    borderRadius = 5;
    defaultTimeout = 5000;
    groupBy = "summary";
    icons = true;
    format = "<b>%s</b>\\n%b";

    extraConfig = ''
      [mode=do-not-disturb]
      invisible=0
    '';
  };

  systemd.user.services.mako = {
    Unit = {
      Description = "Notification daemon";
    };
    Install = {
      WantedBy = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.mako}/bin/mako";
    };
  };
}
