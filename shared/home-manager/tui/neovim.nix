{ pkgs, inputs, ... }:
{
  home.packages = [
    inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default
  ] ++ (with pkgs; [
    gcc
    stylua
    python3
    cargo
    rustc
  ]);
}
