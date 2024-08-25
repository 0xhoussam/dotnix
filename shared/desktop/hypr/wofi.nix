{ pkgs, ... }:
{
  programs.wofi = {
    enable = true;
    settings = {
      xoffset = 710;
      yoffset = 275;
      show = "drun";
      width = 500;
      height = 500;
      always_parse_args = true;
      show_all = true;
      print_command = true;
      layer = "overlay";
      insensitive = true;
      gtk_dark = "true";
      term = "${pkgs.alacritty}/bin/alacritty";
      dynamic_lines = true;
      drun-display_generic = true;
      filter_rate = 250;
      allow_images = true;
      allow_markup = true;
      image_size = "32px";
      normal_window = false;
      no_actions = true;
    };
    style = # css
      ''
        window {
          margin: 0px;
          border: 2px solid #3584e4;
          border-radius: 5px;
          background-color: #242424;
          font-family:
            "sans-serif",
            "Font Awesome 5 free";
          font-size: 16px;
          color: #fafafa;
        }

        #input {
          margin: 5px;
          border: 1px solid #161616;
          border-radius: 20px;
          color: #fafafa;
          background-color: #242424;
        }

        #input image {
          color: #fafafa;
        }

        #inner-box {
          margin: 5px;
          border: none;
          background-color: #242424;
        }

        #outer-box {
          margin: 5px 5px;
          border: none;
          background-color: #262626;
        }

        #scroll {
          margin: 0px;
          border: none;
        }

        #text {
          margin: 5px;
          border: none;
          color: #fafafa;
        }

        #entry:selected {
          background-color: #3584e4;
          color: #fafafa;
          font-weight: normal;
          border-radius: 15px;
        }

        #text:selected {
          background-color: #3584e4;
          color: #fafafa;
          font-weight: normal;
        }
      '';
  };
}
