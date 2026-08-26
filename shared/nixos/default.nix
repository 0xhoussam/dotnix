{ ... }:
{
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./docker.nix
    ./kernel.nix
    ./man.nix
    ./networking.nix
    ./nix.nix
    ./polkit-agent.nix
    ./power.nix
    ./services.nix
    ./shell.nix
    ./sysctl.nix
    ./virt.nix
    ./fonts.nix
    ./xdg.nix
  ];
  config = {
    programs.nix-ld.enable = true;
    security.rtkit.enable = true;
    environment.homeBinInPath = true;
    fonts.enableDefaultPackages = true;
    hardware.enableAllFirmware = true;
  };
  config.nixpkgs.config.allowUnfree = true;
}
