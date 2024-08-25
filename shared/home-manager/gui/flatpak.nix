{ ... }:
{
  services.flatpak.overrides = {
    global = {
      # Force Wayland by default
      Context.sockets = [
        "wayland"
        "!x11"
        "!fallback-x11"
      ];

      Environment = {
        GTK_THEME = "adw-gtk3-dark";
      };
    };
  };
  services.flatpak.packages = [
    "org.gnome.Calculator"
    "com.boxy_svg.BoxySVG"
    "com.getpostman.Postman"
    "com.github.flxzt.rnote"
    "com.github.rafostar.Clapper"
    "com.github.tchx84.Flatseal"
    "com.raggesilver.BlackBox"
    "com.toolstack.Folio"
    "com.usebottles.bottles"
    "info.febvre.Komikku"
    "io.github.alainm23.planify"
    "io.github.mrvladus.List"
    "io.missioncenter.MissionCenter"
    "md.obsidian.Obsidian"
    "net.nokyan.Resources"
    "org.gnome.Calculator"
    "org.gnome.Calendar"
    "org.gnome.Loupe"
    "org.gnome.Snapshot"
    "org.gnome.TextEditor"
    "org.gnome.baobab"
    "org.gtk.Gtk3theme.adw-gtk3"
    "org.gtk.Gtk3theme.adw-gtk3-dark"
    "org.inkscape.Inkscape"
    "org.mozilla.Thunderbird"
    "org.nickvision.tubeconverter"
    "us.zoom.Zoom"
  ];
}
