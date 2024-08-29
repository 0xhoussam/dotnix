{ ... }:
{
  programs.zsh = {
    enable = true;
    zsh-abbr = {
      enable = true;
      abbreviations = {
        v = "nvim";
        nv = "neovide";
        m = "make -j `nproc`";
      };
    };
    shellAliases = {
      ls = "eza --icons";
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
        "sudo"
      ];
      theme = "afowler";
      extraConfig = # bash
        ''
          typeset -A ZSH_HIGHLIGHT_STYLES
          ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#6d6d6d'
          ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#6d6d6d'

          # this update zellij tab name to match the current running process
          function change_tab_name() {
              local title=$1
              command nohup zellij action rename-tab $title >/dev/null 2>&1
            }
          function set_tab_to_command_line() {
              local cmd=$1
              change_tab_name ''\${''\${cmd%% *}}
          }
          function unset_tab_to_command_line() {
              change_tab_name zsh
          }

          if [[ -n $ZELLIJ ]]; then
              add-zsh-hook preexec set_tab_to_command_line
              add-zsh-hook precmd unset_tab_to_command_line
          fi
        '';
    };
  };
}