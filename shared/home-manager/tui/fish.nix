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

    shellInitLast = ''
      fish_vi_key_bindings
      set fish_greeting
    '';

    functions = {
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
