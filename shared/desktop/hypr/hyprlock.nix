{ ... }:
let
  background = ../../../assets/wallpapers/lock.jpg;
in
{
  programs.hyprlock.enable = true;
  programs.hyprlock.settings = {
    general = {
      hide_cursor = true;
      grace = 1;
      ignore_empty_input = true;
    };

    background = [
      {
        path = builtins.toString background; # only png supported for now
        color = "rgba(25, 20, 20, 1.0)";
        blur_passes = 1; # 0 disables blurring
        blur_size = 30;
        contrast = "0.8916";
        brightness = "0.7";
      }
    ];

    # input-field = {
    #   size = "300, 40";
    #   outline_thickness = 1;
    #
    #   outer_color = "rgb(1c71d8)";
    #   inner_color = "rgb(255, 255, 255)";
    #   font_color = "rgb(1e1e1e)";
    #
    #   fade_on_empty = true;
    #   fade_timeout = 1000;
    #   placeholder_text = "<i>Password...</i>";
    #   hide_input = false;
    #   rounding = -1;
    #   check_color = "rgb(e5a50a)";
    #   fail_color = "rgb(e01b24)";
    #   fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
    #   fail_transition = 300;
    #   capslock_color = -1;
    #   numlock_color = -1;
    #   bothlock_color = -1;
    #   invert_numlock = false;
    #   swap_font_color = false;
    #
    #   position = "0, -40";
    #   halign = "center";
    #   valign = "center";
    # };
  };
}
