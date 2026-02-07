{ ... }:
{
  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = true;
      extraConfig = ''
                Host github.com
        Hostname ssh.github.com
        Port 443
        User git

        Host marwa-prod-manager.diptyx.com
        ForwardAgent yes
      '';
    };
  };
}
