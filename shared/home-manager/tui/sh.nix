{ ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "colored-man-pages"
        "docker"
        "docker-compose"
        "zsh-vi-mode"
        "sudo"
      ];
      theme = "afowler";
      extraConfig = # zsh
        ''
          ZSH_HIGHLIGHT_STYLES[flag]='fg=gray'
        '';
    };
  };
}
