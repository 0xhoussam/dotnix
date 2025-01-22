{
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "adwaita-font";
  version = "1.0.0";

  src = ./font;

  installPhase = ''
    runHook preInstall

    install -Dm644 *.ttf -t $out/share/fonts/truetype

    runHook postInstall
  '';
}
