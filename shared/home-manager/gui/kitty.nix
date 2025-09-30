{ ... }:
{
  programs.kitty.enable = true;
  programs.kitty.extraConfig = ''
            allow_remote_control yes

            map super+u           set_background_opacity 1
            map super+shift+u     set_background_opacity default
            map super+shift+i     set_background_opacity 0.9

            font_size 13.0

            shell_integration no-cursor
            enable_audio_bell no

            # dynamic_background_opacity yes
            hide_window_decorations yes
            window_padding_width 4
            window_padding_height 0
            background_blur 10
            placement_strategy top

            cursor_trail 10
            cursor_trail_start_threshold 0
            shell_integration no-cursor
            cursor_trail_decay 0.01 0.15
            cursor_shape block
            cursor_blink true

            background_opacity 1
            set_background_opacity 1

            background #161616
            foreground #f2f4f8
            selection_background #2a2a2a
            selection_foreground #f2f4f8
            cursor_text_color #161616
            url_color #25be6a

            cursor #f2f4f8

            active_border_color #78a9ff
            inactive_border_color #535353
            bell_border_color #3ddbd9

            active_tab_background #78a9ff
            active_tab_foreground #0c0c0c
            inactive_tab_background #2a2a2a
            inactive_tab_foreground #6e6f70

            color0 #282828
            color1 #ee5396
            color2 #25be6a
            color3 #08bdba
            color4 #78a9ff
            color5 #be95ff
            color6 #33b1ff
            color7 #dfdfe0

            color8 #484848
            color9 #f16da6
            color10 #46c880
            color11 #2dc7c4
            color12 #8cb6ff
            color13 #c8a5ff
            color14 #52bdff
            color15 #e4e4e5

            color16 #3ddbd9
            color17 #ff7eb6


            font_family      family="Zenbones Proto"
            bold_font        auto
            italic_font      auto
            bold_italic_font auto
            modify_font cell_width 110%
  '';
}
