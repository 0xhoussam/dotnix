{
  description = "My Awesome Desktop Shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ags,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pname = "my-shell";
    entry = "app.tsx";

    astalPackages = with ags.packages.${system}; [
      io
      astal4 # gtk4 bar
      astal3 # gtk3 lock screen
      auth # AstalAuth: PAM authentication
      hyprland # keyboard layout
      network # wifi indicator
      bluetooth # bluetooth devices
      battery # battery indicator
      wireplumber # volume / audio
      notifd # notifications
      mpris # media player (now playing)
      tray # StatusNotifierItem system tray
    ];

    extraPackages =
      astalPackages
      ++ [
        pkgs.libadwaita
        pkgs.libsoup_3
        pkgs.gtk-session-lock # ext-session-lock-v1 (GtkSessionLock typelib)
        pkgs.eslint_d
      ];
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

        buildInputs = extraPackages ++ [pkgs.gjs];

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
  };
}
