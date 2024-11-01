{
  pkgs,
  ...
}:
{

  programs.hyprland = {
    enable = true;
  };
  programs.dconf.enable = true;

  programs.thunar.enable = true;
  programs.xfconf.enable = true;
  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman # auto mount
  ];

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
