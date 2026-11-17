{ ... }:
{
  # Firefox through Home Manager so Stylix can theme it (homes/pride/stylix.nix).
  # `path` is the profile that already exists, so nothing is lost: Home
  # Manager writes user.js and chrome/ into it and keeps profiles.ini in sync.
  programs.firefox = {
    enable = true;
    profiles.default = {
      id = 0;
      isDefault = true;
      path = "pF7BNIP0.Profile 1";
      # Stylix installs the Firefox Color theme extension and its settings;
      # without this, Home Manager refuses to replace the existing ones.
      extensions.force = true;
    };
  };
}
