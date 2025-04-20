{ pkgs, ... }:
{
  programs.zathura = {
    enable = true;
    extraConfig = ''
      set recolor-lightcolor "rgba(0, 0, 0, 0)"
      set recolor-darkcolor "rgba(255, 255, 255, 0.9)"
      map i recolor
      set recolor true
      set adjust-open "best"
      set guioptions none
      map j feedkeys "<C-Down>"
      map k feedkeys "<C-Up>"
    '';
  };
}
