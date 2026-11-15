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
    ./claude-desktop.nix
  ];
}
