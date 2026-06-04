{ inputs, pkgs, ... }:
let
  bar = inputs.components.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # AGS bar as a user service (restart-on-failure, journalctl --user -u ags-bar).
  systemd.user.services.ags-bar = {
    Unit = {
      Description = "AGS desktop bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${bar}/bin/my-shell";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
