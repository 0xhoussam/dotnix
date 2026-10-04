{ pkgs, ags, ... }:
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
      pkgs.gtk-session-lock
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
}