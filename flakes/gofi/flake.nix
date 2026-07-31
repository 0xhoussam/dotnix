{
  description = "A simple GTK4 app launcher inspired by rofi, using Adwaita";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      in {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "gofi";
          version = "0.1.0";

          src = pkgs.fetchFromGitHub {
            owner = "ulysg";
            repo = "gofi";
            rev = "bb415a52fc1e59108f398417aa0b4f04ffaacb9f";
            sha256 = "0ir09d554av0lwj01am66gxvxlrr2q3ci624p3y1k7h7411sdnqd";
          };

          nativeBuildInputs = with pkgs; [
            meson
            ninja
            pkg-config
          ];

          buildInputs = with pkgs; [
            gtk4-layer-shell
            libadwaita
          ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp gofi $out/bin/
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "A simple GTK4 app launcher inspired by rofi, using Adwaita";
            homepage = "https://github.com/ulysg/gofi";
            license = licenses.mit;
            maintainers = with maintainers; [ ];
            mainProgram = "gofi";
            platforms = platforms.linux;
          };
        };
      });
}