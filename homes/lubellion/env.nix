{ ... }:
let
  wayland = "wayland";
in
{
  home.sessionVariables = {
    SDL_VIDEODRIVER = wayland;
    MOZ_ENABLE_WAYLAND = 1;
    HYPRLAND_LOG_WLR = 1;
    # GDK_BACKEND = 1;
  };
}
