{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../shared/nixos
    ./xdg.nix
    ./services.nix
    ./pkgs.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.cleanTmpDir = true;

  networking.hostName = "project";

  time.timeZone = "Africa/Casablanca";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  users.users.pride = {
    isNormalUser = true;
    initialPassword = "toor";
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ vim ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  system.stateVersion = "24.05";
}
