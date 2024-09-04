{ inputs, pkgs, ... }:
{
  home.packages = with pkgs; [
    brave
    clapper
    gnome-calculator
    loupe
    mpv
    pavucontrol
    planify
    postman
    qbittorrent
    rnote
    transmission_4-gtk
    zathura
    zoom-us

    devenv
    tokei
    whois

    atool
    axel
    bat
    bind
    btop
    curl
    delta
    exiftool
    eza
    fd
    file
    git
    github-cli
    glow
    killall
    nettools
    nftables
    p7zip
    procps
    ripgrep
    sof-firmware
    tree
    unzip
    wget
    wl-clipboard
    zip

    (writeShellScriptBin "reload-failed-services" ''
      systemctl --user list-units --failed | grep -Po '([A-Za-z-0-9]+.service)' | xargs systemctl --user restart
    '')

    (pkgs.callPackage ./custom-packages/harper.nix { })
  ];

  programs = {
    direnv.enable = true;
    firefox = {
      enable = true;
      package = inputs.firefox.packages.${pkgs.system}.firefox-nightly-bin;
    };
  };
}
