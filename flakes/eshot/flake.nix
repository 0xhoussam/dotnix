{
  description = "Native screenshot, annotation, OCR, visual-search, upload, GIF, and video capture tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation rec {
          pname = "eshot";
          version = "4.1.6";

          src = pkgs.fetchFromGitHub {
            owner = "Benoks";
            repo = "EShot";
            rev = "v${version}";
            hash = "sha256-AN0UjpacATJQ3U6LKN106oXDHsjuQclLnwxra9xnnPc=";
          };

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            qt6.wrapQtAppsHook
            pkg-config
          ];

          buildInputs = with pkgs; [
            qt6.qtbase
            qt6.qtwayland
            qt6.qtsvg
            libxkbcommon
            libX11
            desktop-file-utils
            appstream
          ];

          cmakeFlags = [
            "-G Ninja"
            "-DCMAKE_BUILD_TYPE=Release"
          ];

          dontWrapQtApps = false;

          meta = with pkgs.lib; {
            description = "Screenshot, annotation, OCR, upload, GIF and video capture tool";
            homepage = "https://github.com/Benoks/EShot";
            license = licenses.mit;
            platforms = platforms.linux;
            mainProgram = "EShot";
            maintainers = [ ];
          };
        };
      }
    );
}
