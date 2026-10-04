{ pkgs, ... }:
let
  lib = pkgs.lib;
  zenbones =
    { family, unhinted, hash }:
    pkgs.stdenvNoCC.mkDerivation rec {
      pname = "zenbones-${lib.toLower family}";
      version = "2.400";
      src = pkgs.fetchzip {
          url = "https://github.com/zenbones-theme/zenbones-mono/releases/download/v2.400/Zenbones-Proto-TTF.zip";
          hash = "sha256-lxUIew2xwDnHnthIhsK3GfB/NlGzY3dZarBWYEAvJrg=";
      };
      dontUnpack = true;
      sourceRoot = ".";
      installPhase = ''
          runHook preInstall
        mkdir -p $out/share/fonts/truetype
          find $src -type f -name '*.ttf'  -exec install -Dm644 {} -t $out/share/fonts/truetype \;
          runHook postInstall
      '';
    };
in {
  packages.x86_64-linux = {
    zenbones-mono = zenbones {
      family = "Mono";
      unhinted = true;
      hash = "sha256-o12/tFOoeheChs/Z2ehDrg0ODBymDEx2pjSnyNu1GxU=";
    };
    zenbones-brainy = zenbones {
      family = "Brainy";
      unhinted = true;
      hash = "sha256-o12/tFOoeheChs/Z2ehDrg0ODBymDEx2pjSnyNu1GxU=";
    };
    zenbones-prose = zenbones {
      family = "Prose";
      unhinted = true;
      hash = "sha256-o12/tFOoeheChs/Z2ehDrg0ODBymDEx2pjSnyNu1GxU=";
    };
    zenbones-proto = zenbones {
      family = "Proto";
      unhinted = true;
      hash = "sha256-o12/tFOoeheChs/Z2ehDrg0ODBymDEx2pjSnyNu1GxU=";
    };
    zenbones-slab = zenbones {
      family = "Slab";
      unhinted = true;
      hash = "sha256-o12/tFOoeheChs/Z2ehDrg0ODBymDEx2pjSnyNu1GxU=";
    };
  };
}
