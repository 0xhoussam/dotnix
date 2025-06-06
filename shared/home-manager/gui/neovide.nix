{ ... }:
let
  font = "Input Mono Condensed";
in
{
  programs.neovide = {
    enable = true;
    settings = {
      fork = false;
      frame = "full";
      idle = true;
      maximized = false;
      no-multigrid = false;
      srgb = false;
      tabs = true;
      theme = "auto";
      title-hidden = true;
      vsync = true;
      wsl = false;
      box-drawing = {
        mode = "native";
      };
      font = {
        normal = [
          {
            family = font;
            weight = "Regular";
          }
        ];
        bold = [
          {
            family = font;
            weight = "Bold";
          }
        ];
        size = 14;
      };
    };
  };
}
