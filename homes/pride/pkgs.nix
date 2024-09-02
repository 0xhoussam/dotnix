{ inputs, pkgs, ... }:
{
  home.packages = with pkgs; [
    qbittorrent
    mpv
    zathura
    pavucontrol
    brave

    devenv
    tokei
    whois

    file
    killall
    btop
    wget
    curl
    axel
    git
    tree
    bat
    eza
    ripgrep
    fd
    procps
    zip
    unzip
    p7zip
    github-cli
    glow
    delta
    exiftool
    atool
    nettools
    nftables
    sof-firmware
    bind
    wl-clipboard

    nautilus

    (writeShellScriptBin "reload-failed-services" ''
      systemctl --user list-units --failed | grep -Po '([A-Za-z-0-9]+.service)' | xargs systemctl --user restart
    '')
  ];

  programs = {
    direnv.enable = true;
    firefox = {
      enable = true;
      package = inputs.firefox.packages.${pkgs.system}.firefox-nightly-bin;
    };
    xfconf.enable = true;
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };
  };
}
