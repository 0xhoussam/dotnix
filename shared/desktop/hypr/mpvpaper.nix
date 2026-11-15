{ pkgs, lib, ... }:
let
  wallpaper = ../../../assets/wallpapers/misty-valley.mp4;
  # Silent, looped, cropped to fill; -p pauses playback while the wallpaper
  # is hidden (-p), including behind a fullscreen window (-a FULL), to save
  # power. The shell also freezes it while on battery.
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
      ExecStart = "${lib.getExe pkgs.mpvpaper} -p -a FULL -o '${mpvOptions}' ALL ${wallpaper}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
