{
  pkgs,
  ...
}:
{

  environment.systemPackages = with pkgs; [
    uutils-coreutils-noprefix
    clinfo
    gns3-server
  ];
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
}
