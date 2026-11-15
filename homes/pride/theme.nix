{ pkgs, ... }:
{
  # Colours, fonts, the GTK theme and the Qt style come from Stylix
  # (homes/pride/stylix.nix). What stays here: the icon theme and dconf.
  gtk = {
    enable = true;
    iconTheme = {
      name = "Numix-Circle";
      package = pkgs.numix-icon-theme-circle;
    };
  };

  dconf.enable = true;
  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
    "org/gnome/TextEditor" = {
      keybindings = "vim";
    };
    "org/gnome/desktop/interface" = {
      icon-theme = "Numix-Circle";
    };
  };
}
