{ pkgs, ... }:
{
  programs.neovim.enable = true;
  home.file = {
    ".config/nvim" = {
      source = pkgs.fetchFromGitHub {
        owner = "0xhoussam";
        repo = "neovim";
        rev = "18a0add7cefdc47b47c88bb2230f0c32c44af1db";
        sha256 = "sha256-gqAi4Lq58//sYQl6p7ReGVicF46o12NO9IL80m9zacM=";
      };
    };
  };
}
