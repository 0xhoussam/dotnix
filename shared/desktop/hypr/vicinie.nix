{ ... }:
{
  services.vicinae = {
    enable = true;
    autoStart = true;
    settings = {
      faviconService = "twenty"; # twenty | google | none
      font.size = 11;
      popToRootOnClose = false;
      rootSearch.searchFiles = false;
      theme.name = "vicinae-dark";
      window = {
        csd = true;
        opacity = 0.95;
        rounding = 10;
      };
    };
    # Installing (vicinae) extensions declaratively
    # extensions = [
      # (inputs.vicinae.mkVicinaeExtension.${pkgs.system} {
      #   inherit pkgs;
      #   name = "extension-name";
      #   src = pkgs.fetchFromGitHub { # You can also specify different sources other than github
      #     owner = "repo-owner";
      #     repo = "repo-name";
      #     rev = "v1.0"; # If the extension has no releases use the latest commit hash
      #     # You can get the sha256 by rebuilding once and then copying the output hash from the error message
      #     sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      #   }; # If the extension is in a subdirectory you can add ` + "/subdir"` between the brace and the semicolon here
      # })
    # ];
  };

}
