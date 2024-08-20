{ pkgs, ... }:
{
  programs.neovim.enable = true;
  home.file = {
    ".config/nvim" = {
      source = pkgs.fetchFromGitHub {
        owner = "0xhoussam";
        repo = "neovim";
        rev = "6a9992fe00057a595e0a4ec0cd0a0faf9f31ca52";
        sha256 = "sha256-siMky/WFvhjnS1+t0zEx++omWv/QM3kbA431uTltJ8s=";
      };
    };
  };
}
