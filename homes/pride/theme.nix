{ pkgs, ... }:
{
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };
    cursorTheme = {
      package = pkgs.yaru-theme;
      name = "Yaru-dark";
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
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    name = "Yaru-dark";
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.yaru-theme;
    size = 22;
  };
}
