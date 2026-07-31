{ ... }:
{
  programs.sherlock = {
    enable = true;
    settings = {
      keybinds = {
        "return" = "exec";
      };
    };
  };
}
