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

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    font = {
      name = "SFProDisplay Nerd Font";
      size = 11;
      package = inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd;
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

  dconf.enable = true;
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
