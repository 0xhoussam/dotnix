{
  config,
  pkgs,
  components,
  ...
}:

let
  shellPkgs = components.packages.${pkgs.stdenv.hostPlatform.system};

  # Border colour: the Stylix accent when Stylix is enabled for this user, else the old blue.
  borderActive =
    if (config.stylix.enable or false) then "0xff${config.lib.stylix.colors.base0D}" else "0xff1c71d8";

  # The config itself is hand written (hyprland.lua next to this file) and
  # symlinked straight from the checkout, so edits apply with `hyprctl reload`
  # and no rebuild. Only the Stylix colour is generated.
  checkout = "${config.home.homeDirectory}/dotnix/shared/desktop/hyprland";
in
{
  imports = [
    ./hypridle.nix
    ./env.nix
    ./service.nix
  ];

  # Programs the config calls by name.
  home.packages = [
    pkgs.playerctl
    pkgs.brightnessctl
    pkgs.wireplumber
    shellPkgs.qs-lock # lock-screen
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    systemd.variables = [ "--all" ];
    systemd.enableXdgAutostart = true;
    # Never written: hyprland.lua below replaces the generated file. A non-empty
    # value only silences Home Manager's "no configuration" warning.
    extraConfig = "-- see hyprland.lua";
  };

  # Replaces the file Home Manager would generate. Startup and shutdown hooks
  # live in hyprland.lua.
  xdg.configFile."hypr/hyprland.lua".source = pkgs.lib.mkForce (
    config.lib.file.mkOutOfStoreSymlink "${checkout}/hyprland.lua"
  );
  xdg.configFile."hypr/nix.lua".text = ''
    return { borderActive = "${borderActive}" }
  '';
}
