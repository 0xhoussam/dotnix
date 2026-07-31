{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ForwardAgent = true;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        SetEnv = {
            TERM = "xterm-256color";
        };
      };
      "github.com" = {
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
      };
      "marwa-prod-manager.diptyx.com" = {
        ForwardAgent = true;
      };
    };
  };
}
