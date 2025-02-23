{ ... }:
{
  programs.zsh = {
    enable = true;
    zsh-abbr = {
      enable = true;
      abbreviations = {
        g = "git";
        v = "nvim";
        m = "make -j `nproc`";
        zl = "zellij";
        open = "xdg-open";
      };
    };
    shellAliases = {
      ls = "eza --icons";
      "nix-update" = "sudo nixos-rebuild switch";
      "hm-update" = "home-manager switch -b backup --flake .#pride";
    };
    zplug = {
      enable = true;
      plugins = [
        { name = "zsh-users/zsh-syntax-highlighting"; }
        { name = "jeffreytse/zsh-vi-mode"; }
        { name = "zsh-users/zsh-autosuggestions"; }
        { name = "olets/zsh-abbr"; }
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
          ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#898989'
          ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#898989'
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#898989"

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

          eval "$(zoxide init zsh)"
        '';
    };
  };
}
