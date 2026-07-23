{ ... }:
{
  programs.sherlock = {
    enable = true;
    settings = {
      appearance = {
        width = 800;
        height = 500;
        icon_size = 24;
        opacity = 1.0;
        use_base_css = true;
      };
      backdrop = {
        enable = true;
        opacity = 0.6;
      };
      status_bar.enable = false;
      behavior.animate = true;
    };
    style = ''
      window {
        border-radius: 12px;
      }
      window.background {
        border: 1px solid alpha(@accent_bg_color, 0.3);
        border-radius: 12px;
      }
      entry {
        margin: 8px 12px;
        padding: 8px 12px;
        border-radius: 8px;
        font-size: 1.1em;
      }
      listview, list {
        margin: 0 4px 4px;
      }
      listview > row,
      list > row {
        margin: 1px 8px;
        padding: 6px 10px;
        border-radius: 6px;
      }
      listview > row:selected,
      list > row:selected {
        background-color: alpha(@accent_bg_color, 0.3);
      }
      listview > row label,
      list > row label {
        font-size: 0.95em;
      }
      listview > row label:first-child,
      list > row label:first-child {
        font-weight: 500;
      }
      listview > row image,
      list > row image {
        margin-right: 8px;
      }
      listview > row:selected image,
      list > row:selected image {
        -gtk-icon-filter: brightness(1.2);
      }
    '';
  };
}
