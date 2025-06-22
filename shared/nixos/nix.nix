{ ... }:
{
  nix = {
    optimise.automatic = true;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };

    settings = {
      sandbox = true;
      experimental-features = [
        "nix-command"
        "flakes"
        "read-only-local-store"
      ];
      trusted-users = [ "@wheel" ];
      auto-optimise-store = true;
      warn-dirty = false;
      substituters = [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

    };
  };
}
