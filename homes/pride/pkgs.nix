{
  inputs,
  pkgs,
  eshot,
  ...
}:
{
  home.packages = with pkgs; [
    brave
    mpv
    pavucontrol
    ghostty
    firefox
    spotify
    imv
    opencode
    anyrun
    inputs.mcmojave-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    eshot.packages.${pkgs.stdenv.hostPlatform.system}.default
    loupe
    gnome-text-editor
    gns3-gui
    inetutils
    wireshark
    papers
    helix
    lutris
        wine

    zoom-us
    proton-vpn

    devenv
    tokei
    whois
    nixd
    nixfmt

    atool
    axel
    bind
    btop
    curl
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
    zoxide
    yt-dlp
    ffmpeg
    (writeShellScriptBin "reload-failed-services" ''
      systemctl --user list-units --failed | grep -Po '([A-Za-z-0-9]+.service)' | xargs systemctl --user restart
    '')
  ];

  programs = {
    direnv.enable = true;
    zed-editor = {
      enable = true;
      extraPackages = with pkgs; [ nerd-fonts.jetbrains-mono ];

    };
  };
}
