{ pkgs, ... }:
{
  documentation = {
    enable = true;

    dev.enable = true;

    man = {
      enable = true;
      man-db.enable = false;
      mandoc.enable = true;
      cache.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    man-pages
    man-pages-posix
  ];
}
