{ pkgs, ... }:
{
  home.packages = with pkgs; [
    qbittorrent
    mpv
    zathura
    pavucontrol
    brave
    firefox

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
  ];

  programs = {
    direnv.enable = true;
  };
}
