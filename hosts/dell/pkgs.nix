{
  ...
}:
{

  programs.hyprland = {
    enable = true;
  };
  programs.dconf.enable = true;

  programs.xfconf.enable = true;

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.nm-applet = {
    enable = true;
    indicator = true;
  };

  programs.steam = {
    enable = true;
  };
}
