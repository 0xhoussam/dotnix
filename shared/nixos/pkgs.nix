{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    neovim
    git
    curl
    zsh
    tuigreet
  ];
}
