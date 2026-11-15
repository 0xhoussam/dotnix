# The desktop shell around Hyprland: bar service, wallpaper, launcher, clipboard.
# The shell itself lives in pkgs/desktop-shell.
{ pkgs, ... }:
{
  imports = [
    ./shell.nix
    ./mpvpaper.nix
    ./anyrun.nix
  ];

  home.packages = [ pkgs.cliphist ];
  services.cliphist.enable = true;
}
