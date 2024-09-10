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
      aliases = {
        # add
        a = "add";
        aa = "add -all";

        # commit
        c = "commit";
        cm = "commit -m";
        cam = "commit -am";

        # status
        s = "status";

        # push
        p = "push";

        # pull
        pl = "pull";

        # clone
        cl = "clone";
        cls = "clone --depth=1"; # shallow clone

        # diff
        d = "diff";
        ds = "diff --staged";

        # log
        l = "log";
        lo = ''log --pretty=format:"%C(yellow)%h %ad%Cred%d %Creset%s%Cblue [%cn]" --decorate --date=short'';

        # stash
        staash = "stash --all";

        # branch
        b = "!git for-each-ref --sort='-authordate' --format='%(authordate)%09%(objectname:short)%09%(refname)' refs/heads | sed -e 's-refs/heads/--'";
      };
    };
  };
}
