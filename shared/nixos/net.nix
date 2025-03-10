{ ... }:
{
  networking.networkmanager.enable = true;

  networking.nftables.enable = true;
  networking.firewall.enable = true;
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
    # dnssec = "true";
    # dnsovertls = "true";
    # domains = [ "~." ];
    fallbackDns = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "8.8.8.8#dns.google"
      "8.4.4.8#dns.google"
    ];
  };
}
