{ inputs, pkgs, ... }:
{
  home.packages = with pkgs; [
    qbittorrent
    mpv
    zathura
    pavucontrol
    brave
    zoom-us
    transmission-gtk
    loupe
    planify
    clapper
    rnote
    postman
    gnome.gnome-calculator

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
  };
}
