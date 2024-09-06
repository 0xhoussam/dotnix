{ inputs, pkgs, ... }:
let
  zen-browser = inputs.zen-browser.packages."${pkgs.system}".default;
in
{
  home.packages = with pkgs; [
    brave
    mpv
    pavucontrol
    postman
    qbittorrent

    zathura
    zoom-us
    zen-browser

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
