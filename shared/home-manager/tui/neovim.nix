{ pkgs, inputs, ... }:
{
  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      gcc
      stylua
      python3
    ];
  };
}
