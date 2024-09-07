{ inputs, pkgs, ... }:
{
  imports = [
    inputs.kvlibadwaita.homeManagerModule
  ];
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };
    cursorTheme = {
      package = pkgs.phinger-cursors;
      name = "phinger-cursors-darkr";
      size = 22;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "IBM Plex Sans Condensed";
      size = 11;
      package = pkgs.ibm-plex;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=KvLibadwaitaDark
  '';
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    kvlibadwaita = {
      enable = true;
      auto = false;
    };
  };

  home.pointerCursor = {
    name = "phinger-cursors-dark";
    package = pkgs.phinger-cursors;
    size = 22;
    gtk.enable = true;
  };

  dconf.enable = true;
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
