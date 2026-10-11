{
  pkgs,
  ags,
  # video (or image) for the lock screen background; null = dark gradient
  lockWallpaper ? null,
  ...
}:
let
  system = "x86_64-linux";
  pname = "my-shell";
  entry = "app.tsx";

  astalPackages = with ags.packages.${system}; [
    io
    astal4
    astal3
    auth
    hyprland
    network
    bluetooth
    battery
    wireplumber
    notifd
    mpris
    tray
  ];

  extraPackages =
    astalPackages
    ++ [
      pkgs.libadwaita
      pkgs.libsoup_3
      pkgs.libsecret # network agent: agent-owned Wi-Fi/VPN secrets in the keyring
      pkgs.eslint_d
    ];
  # Lock screen extras: GStreamer for the video wallpaper (Gtk.MediaFile;
  # va = hardware decode, libav = software fallback) and its HUD font,
  # added on top of the system fontconfig.
  lockPackages = with pkgs.gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-libav
  ];
  lockFonts = pkgs.writeText "lock-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${pkgs.orbitron}/share/fonts</dir>
    </fontconfig>
  '';
in {
  packages.${system} = {
    default = pkgs.stdenv.mkDerivation {
      name = pname;
      src = ./.;

      nativeBuildInputs = with pkgs; [
        wrapGAppsHook3
        gobject-introspection
        ags.packages.${system}.default
      ];

      buildInputs = extraPackages ++ [pkgs.gjs];

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        mkdir -p $out/share
        cp -r * $out/share
        ags bundle ${entry} $out/bin/${pname} -d "SRC='$out/share'"

        runHook postInstall
      '';
    };

    lock = pkgs.stdenv.mkDerivation {
      name = "lock-screen";
      src = ./.;

      nativeBuildInputs = with pkgs; [
        wrapGAppsHook3
        gobject-introspection
        ags.packages.${system}.default
      ];

      buildInputs = extraPackages ++ lockPackages ++ [pkgs.gjs];

      # --set-default so `LOCK_WALLPAPER=... lock-screen` can still override it
      preFixup =
        ''
          gappsWrapperArgs+=(--set FONTCONFIG_FILE ${lockFonts})
        ''
        + pkgs.lib.optionalString (lockWallpaper != null) ''
          gappsWrapperArgs+=(--set-default LOCK_WALLPAPER ${lockWallpaper})
        '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        mkdir -p $out/share
        cp -r * $out/share
        ags bundle lock/app.tsx $out/bin/lock-screen -d "SRC='$out/share'"

        runHook postInstall
      '';
    };
  };

  devShells.${system} = {
    default = pkgs.mkShell {
      buildInputs = [
        (ags.packages.${system}.default.override {
          inherit extraPackages;
        })
      ];
    };
  };
}