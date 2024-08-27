{ ... }:
{
  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";

    input = {
      kb_layout = "us";
      follow_mouse = 1;
      touchpad = {
        natural_scroll = true;
        clickfinger_behavior = true;
      };
    };

    device = {
      name = "elan-touchscreen";
      enabled = false;
    };

    decoration = {
      rounding = 0;
      blur = {
        enabled = true;
        size = 3;
        passes = 1;
        new_optimizations = "on";
      };

      drop_shadow = "yes";
      shadow_range = 4;
      shadow_render_power = 3;
      col.shadow = "rgba(1a1a1aee)";
    };
  };
}
