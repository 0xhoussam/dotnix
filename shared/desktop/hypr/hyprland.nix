{
  inputs,
  pkgs,
  lib,
  self,
  config,
  components,
  ...
}:

let
  # Border colour: the Stylix accent when Stylix is enabled for this user, else the old blue.
  borderActive =
    if (config.stylix.enable or false) then "0xff${config.lib.stylix.colors.base0D}" else "0xff1c71d8";
  playerctl = lib.getExe pkgs.playerctl;
  lock = "${components.packages.${pkgs.stdenv.hostPlatform.system}.qs-lock}/bin/lock-screen";
  # `shell-ctl shell osd brightness`, `shell-ctl shell toggle volume`, ... talk to the running bar
  shellCtl = "${components.packages.${pkgs.stdenv.hostPlatform.system}.qs-shell}/bin/shell-ctl";
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  hyprshot = lib.getExe pkgs.hyprshot;
  kitty = lib.getExe pkgs.kitty;
  firefox = lib.getExe pkgs.firefox;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  wpctl = "${pkgs.wireplumber}/bin/wpctl";

  # The real config is hyprland-live.lua, read straight from the checkout so
  # edits apply with `hyprctl reload` and no rebuild. Only store paths and the
  # accent colour are generated here. If the checkout is missing, the copy in
  # the store is used instead.
  hyprlandLua = /* lua */ ''
    NIX = {
      borderActive = "${borderActive}";
      brightnessctl = "${brightnessctl}";
      firefox = "${firefox}";
      hyprctl = "${hyprctl}";
      hyprshot = "${hyprshot}";
      kitty = "${kitty}";
      lock = "${lock}";
      playerctl = "${playerctl}";
      shellCtl = "${shellCtl}";
      wpctl = "${wpctl}";
    }
    local live = os.getenv("HOME") .. "/dotnix/shared/desktop/hypr/hyprland-live.lua"
    local f = io.open(live)
    if f then f:close() else live = "${./hyprland-live.lua}" end
    dofile(live)
  '';

in
{
  imports = [
    ./hypridle.nix
    ./env.nix
    ./service.nix
    ./shell.nix
    ./anyrun.nix
  ];

  home.packages = [
    pkgs.playerctl
    pkgs.hyprshot
    pkgs.brightnessctl
    pkgs.wireplumber
  ];

  wayland.windowManager.hyprland = {
    enable = true;

    # Hyprland >= 0.55 uses Lua.
    configType = "lua";

    systemd.variables = [ "--all" ];
    systemd.enableXdgAutostart = true;

    # IMPORTANT:
    # Do not use `settings` for this Lua configuration.
    #
    # Home Manager's Lua settings generation has had issues with
    # Hyprland's new Lua configuration format.
    extraConfig = hyprlandLua;
  };
}
