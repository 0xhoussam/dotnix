{
  description = "zenbones font flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = nixpkgs.lib;
        zenbones =
          {
            family,
            unhinted,
            hash,
          }:
          pkgs.stdenvNoCC.mkDerivation rec {
            pname = "zenbones-${lib.toLower family}";
            version = "2.400";
            src = pkgs.fetchzip {
              inherit hash;
              url =
                "https://github.com/zenbones-theme/zenbones-mono/releases/download/v${version}/Zenbones-${family}-TTF"
                + (if unhinted == true then "-Unhinted" else "")
                + ".zip";
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
      in
      {
        packages = {
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

    );
}
