{ pkgs, ... }:
{
  programs.bat = {
    enable = true;
    config.theme = "base16";
    themes = {
      fleet = {
        src = pkgs.fetchFromGitHub {
          owner = "knoxydev";
          repo = "fleetish-theme";
          rev = "c694172b073875a16af860264bd3a8d1c752de28";
          sha256 = "sha256-IE1vPjblBKpHHMOodoRNBxEZBDwq70XLZpLKCpVgVqw=";
        };
        file = "Fleetish.sublime-theme";
      };
    };

  };
}
