{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./gui
    ./tui
    ./claude.nix
  ];
}
