{ ... }:
{
  # Docker
    virtualisation.waydroid.enable = true;
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
}
