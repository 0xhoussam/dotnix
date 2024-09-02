{ ... }:
{
  programs.walker = {
    enable = true;
    runAsService = true;

    config = {
      ignore_mouse = true;
      disabled = [
        "finder"
        "runner"
        "windows"
      ];
      list.max_items = 20;
    };

    theme = {
      layout = {
        ui = {
          ignore_mouse = true;
          anchors = {
            bottom = true;
            left = true;
            right = true;
            top = true;
          };
          window = {
            box = {
              h_align = "center";
              margins = {
                bottom = 200;
                top = 200;
              };
              orientation = "vertical";
              scroll = {
                list = {
                  always_show = true;
                  item = {
                    activation_label = {
                      width = 20;
                      x_align = 1;
                    };
                    icon = {
                      theme = "Papirus";
                    };
                    spacing = 5;
                    text = {
                      revert = true;
                    };
                  };
                  width = 400;
                };
                overlay_scrolling = false;
              };
              search = {
                spacing = 10;
                v_align = "start";
                width = 400;
              };
              spacing = 10;
              v_align = "start";
            };
            h_align = "fill";
            v_align = "fill";
          };
        };
      };
      style = # css
        ''
          #window,
          #box,
          #search,
          #password,
          #input,
          #typeahead,
          #spinner,
          #list,
          child,
          scrollbar,
          slider,
          #item,
          #text,
          #label,
          #sub,
          #activationlabel {
            all: unset;
          }

          #window {
            background: none;
            font-family:
              sans-serif;
            font-size: 15px;
          }

          #box {
            background: #242424;
            padding: 16px;
            box-shadow: 0px 0px 28px -8px rgba(30, 30, 30, 0.8);
          }

          scrollbar {
            background: none;
          }

          slider {
            min-width: 2px;
            background: #f3f3f3;
            opacity: 0.5;
          }

          #search {
            border: 2px solid #3584e4;
            border-radius: 8px;
          }

          #password,
          #input,
          #typeahead {
            background: #1e1e1e;
            box-shadow: none;
            border-radius: 7px;
            color: #ffffff;
            padding: 8px 12px;
          }

          #input {
            background: unset;
          }

          #input > *:first-child,
          #typeahead > *:first-child {
            color: #7f849c;
            margin-right: 7px;
          }

          #input > *:last-child,
          #typeahead > *:last-child {
            color: #7f849c;
          }

          #spinner {
          }

          #typeahead {
            color: #383838;
          }

          #input placeholder {
            opacity: 0.5;
          }

          #list {
          }

          child {
            border-radius: 10px;
            color: #ffffff;
            padding: 8px 4px;
          }

          child:selected,
          child:hover {
            background: #3584e4;
            box-shadow: none;
            color: #ffffff;
          }

          #item {
            opacity: 1;
            color: #ffffff;
            font-weight: bold;
          }

          #icon {
          }

          #text {
          }

          #label {
            font-weight: bold;
            color: #ffffff;
          }

          #sub {
            opacity: 0.6;
            color: #ffffff;
          }

          #activationlabel {
            opacity: 0.5;
            padding-right: 4px;
          }

          .activation #activationlabel {
            font-weight: bold;
            color: #89b4fa;
            opacity: 1;
          }

          .activation #text,
          .activation #icon,
          .activation #search {
          }
        '';
    };
  };
}
