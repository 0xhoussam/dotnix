{ config, inputs, pkgs, components, ... }:
let
  bar = components.packages.${pkgs.stdenv.hostPlatform.system}.qs-shell;
in
{
  # Quickshell bar as a user service (restart-on-failure,
  # journalctl --user -u quickshell-bar). It also runs the D-Bus agents
  # (BlueZ pairing, OBEX, NetworkManager secrets) as a child process.
  systemd.user.services.quickshell-bar = {
    Unit = {
      Description = "Quickshell desktop bar";
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
