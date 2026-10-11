{ pkgs, lib, ... }:
let
  wallpaper = ../../../assets/wallpapers/misty-valley.mp4;
  # Silent, looped, cropped to fill; -p pauses playback while the wallpaper
  # is fully covered to save power.
  mpvOptions = "no-audio --really-quiet --loop-file=inf --panscan=1.0 --hwdec=auto";
in
{
  home.packages = [ pkgs.mpvpaper ];

  systemd.user.services.mpvpaper = {
    Unit = {
      Description = "Live video wallpaper";
      Documentation = [ "man:mpvpaper(1)" ];
      PartOf = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.mpvpaper} -p -o '${mpvOptions}' ALL ${wallpaper}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
