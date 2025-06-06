{ pkgs, ... }:
{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./docker.nix
    ./man.nix
    ./net.nix
    ./nix.nix
    ./polkit-agent.nix
    ./power.nix
    ./services.nix
    ./shell.nix
    ./sysctl.nix
    ./virt.nix
    ./polkit-agent.nix
  ];
  config = {
    programs.nix-ld.enable = true;
    security.rtkit.enable = true;
    environment.homeBinInPath = true;
    fonts.enableDefaultPackages = true;
    hardware.enableAllFirmware = true;
  };
  config.nixpkgs.config.allowUnfree = true;
  config.nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];
}
