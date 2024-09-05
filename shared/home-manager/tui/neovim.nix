{ pkgs, ... }:
{
  programs.neovim.enable = true;
  home.file = {
    ".config/nvim" = {
      source = pkgs.fetchFromGitHub {
        owner = "0xhoussam";
        repo = "neovim";
        rev = "88977866d702586d0f119ab4a125f1f676435d88";
        sha256 = "sha256-zeqHwvmwpXZhG5pzkP5VKt7zDOu/YGu0RiB6eYwMJvM=";
      };
    };
  };
}
