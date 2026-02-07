{ ... }:
{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      merge = {
        conflictStyle = "zdiff3";
      };
      line-numbers = true;
      side-by-side = true;
      features = "base16-256";
      true-color = "always";
    };
  };
}
