{ config, pkgs, components, ... }:
let
  shellPkgs = components.packages.${pkgs.stdenv.hostPlatform.system};
  bar = shellPkgs.qs-shell;
  checkout = "${config.home.homeDirectory}/dotnix/flakes/components/shell";
in
{
  # The QML is read from the checkout through a symlink, so edits apply at once
  # (Quickshell reloads on change) with no rebuild.
  xdg.configFile."quickshell/my-shell".source = config.lib.file.mkOutOfStoreSymlink checkout;

  # `shell-ctl toggle volume`, `shell-ctl osd brightness`, ... talk to the running bar.
  home.packages = [
    (pkgs.writeShellScriptBin "shell-ctl" ''exec ${pkgs.quickshell}/bin/qs -c my-shell ipc call "$@"'')
  ];

  # Quickshell bar as a user service (restart-on-failure,
  # journalctl --user -u quickshell-bar). It also runs the D-Bus agents
  # (BlueZ pairing, OBEX, NetworkManager secrets) as a child process.
  # A user unit has a short PATH, so the tools the shell runs are put on it here.
  systemd.user.services.quickshell-bar = {
    Unit = {
      Description = "Quickshell desktop bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/qs -c my-shell";
      Environment = [
        "PATH=${bar.shellTools}:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
        "XDG_DATA_DIRS=${pkgs.adwaita-icon-theme}/share:${config.home.profileDirectory}/share:/run/current-system/sw/share"
        "QS_ICON_THEME=Adwaita"
        "SHELL_AGENTS=${bar.shellAgents}/bin/shell-agents"
        "SHELL_LOCK_CMD=${bar.lock}/bin/lock-screen"
      ];
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
