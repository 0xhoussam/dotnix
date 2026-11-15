{ ... }:
{
  networking.networkmanager.enable = true;

  networking.nftables.enable = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  # Proton VPN (WireGuard/Stealth) replies get dropped under strict reverse-path filtering
  networking.firewall.checkReversePath = "loose";
  networking.hosts = {
    "127.0.0.1" = [ "minio" ];
  };

  # networking.nameservers = [
  #   "1.1.1.1#one.one.one.one"
  #   "1.0.0.1#one.one.one.one"
  #   "8.8.8.8#dns.google"
  #   "8.4.4.8#dns.google"
  # ];

  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "8.8.8.8#dns.google"
      "8.4.4.8#dns.google"
    ];
  };
}
