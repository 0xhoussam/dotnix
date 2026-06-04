{ ... }:
{
  programs.fish.enable = true;
  programs.fish = {
    shellAliases = {
      ls = "eza --icons";
      v = "nvim";
      nv = "neovide";
    };

    shellAbbrs = {
      m = "make -j 4";
      bctl = "bluetoothctl";
      g = "git";
    };

    shellInitLast = # fish
      ''
        fish_vi_key_bindings
        set fish_greeting
        set -g fish_vi_force_cursor 1

        set fish_cursor_default block
        set fish_cursor_insert line
        set fish_cursor_replace_one underscore
        set fish_color_option '#f6f5f4'

        # show full path in prompt (no component shortening)
        set -g fish_prompt_pwd_dir_length 0

        zoxide init fish | source
      '';

    functions = {
      # prompt mirroring oh-my-zsh afowler theme:
      #   bystial :: ~/projects/logistics ‹prod*› »
      _git_prompt = # fish
        ''
          set -l ref (command git symbolic-ref --short HEAD 2>/dev/null; or command git rev-parse --short HEAD 2>/dev/null)
          test -z "$ref"; and return
          set -l dirty ""
          command git --no-optional-locks diff-index --quiet HEAD -- 2>/dev/null; or set dirty "*"
          set_color white
          echo -n " ‹$ref$dirty›"
          set_color normal
        '';

      fish_prompt = # fish
        ''
          set -l last_status $status
          # host (red on previous error)
          set_color white
          test $last_status -ne 0; and set_color red
          echo -n (prompt_hostname)
          set_color normal
          echo -n ' :: '
          # cwd
          set_color cyan
          echo -n (prompt_pwd)
          set_color normal
          # git branch + dirty marker
          _git_prompt
          # prompt char
          echo -n ' » '
        '';

      zellij_tab_name_update_pre = {
        body = # fish
          ''
            if set -q ZELLIJ
                set title (string split ' ' $argv)[1]
                command nohup zellij action rename-tab $title >/dev/null 2>&1
            end
          '';
        onEvent = "fish_preexec";
      };

      zellij_tab_name_update_post = {
        body = ''
          if set -q ZELLIJ
              command nohup zellij action rename-tab (basename $SHELL) >/dev/null 2>&1
          end
        '';
        onEvent = "fish_postexec";
      };
    };
  };
}
