{ ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
    };
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "jeffreytse/zsh-vi-mode"; }
      ];
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "colored-man-pages"
        "docker"
        "docker-compose"
        # "zsh-vi-mode"
        "sudo"
      ];
      theme = "afowler";
      extraConfig = # zsh
        ''
          typeset -A ZSH_HIGHLIGHT_STYLES
          ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#6d6d6d'
          ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#6d6d6d'
        '';
    };
  };
}
