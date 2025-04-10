{ ... }:
{

  services.swayosd = {
    enable = true;
  };
  services.poweralertd.enable = true;
  services.gnome-keyring.enable = true;
  services.network-manager-applet.enable = true;
  services.blueman-applet.enable = true;

}
