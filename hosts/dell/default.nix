{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./../../shared/nixos
    ./xdg.nix
    ./services.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "project";

  time.timeZone = "Africa/Casablanca";

  i18n.defaultLocale = "en_US.UTF-8";

  users.users.pride = {
    isNormalUser = true;
    initialPassword = "toor";
    extraGroups = [ "wheel" ];
    packages = with pkgs; [ vim ];
  };

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs.nm-applet = {
    enable = true;
    indicator = true;
  };

  programs.hyprland.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  system.stateVersion = "24.05";
}
