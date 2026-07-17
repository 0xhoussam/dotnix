{ config, pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./../../shared/nixos
    ./xdg.nix
    ./services.nix
    ./pkgs.nix
    ./intel.nix
    ./power.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.tmp.cleanOnBoot = true;

  networking.hostName = "bystial";

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
    hashedPassword = "WKR1rGFCiDLJou9CtGxGsUOHXCPYy9wSzVFjBbMyfI84UzSDmVRdBYrSzlnXIsl3ZANYumXXbpCqw9VCiqDJM.";
    extraGroups = [
      "wheel"
      "docker"
    ];
    packages = with pkgs; [
      vim
      nemo-with-extensions
    ];
  };

  environment = {
    sessionVariables.NIXOS_OZONE_WL = "1";
    variables = {
      ROC_ENABLE_PRE_VEGA = "1";
    };
  };

  hardware.graphics = {
    enable = true;
  };

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  system.stateVersion = "26.05";
}
