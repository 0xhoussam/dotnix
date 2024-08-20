{ ... }:
{
  programs.git = {
    enable = true;
    userEmail = "owner@0xhoussam.me";
    userName = "Houssam Abouiba";
    includes = [
      {
        condition = "gitdir:~/42";
        contents = {
          user = {
            email = "habouiba@student.1337.ma";
            name = "habouiba";
          };
        };
      }
    ];
    extraConfig = {
      core.excludesfile = "gitignore";
      core.editor = "nvim";
      core.pager = "delta";
      branch.sort = "-committerdate";
      color.ui = "auto";
      init.defaultBranch = "main";
    };
  };
}
