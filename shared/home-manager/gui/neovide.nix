{ ... }:
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
      font = {
        normal = [
          {
            family = "monospace";
          }
        ];
        size = 14.5;
      };
    };
  };
}
