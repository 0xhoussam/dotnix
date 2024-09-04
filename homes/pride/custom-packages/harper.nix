{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "harper";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "elijah-potter";
    repo = pname;
    rev = "17f9ffd1961eb9a760cba29e032623db4db604cd";
    hash = "sha256-DpBCTljIigpyZdiFm8x/bqDn+kzK8ILHpzGqX0d1mI8=";
  };

  cargoHash = "sha256-ZMZq/HRvr+JO/fHBJcyRtKXSzCabxkJRBe6OQjij77g=";

  meta = with lib; {
    description = "The Grammar Checker for Developers";
    homepage = "https://writewithharper.com/";
    license = licenses."asl20";
    maintainers = [ ];
  };
}
