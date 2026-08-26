{
  inputs,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    brave
    mpv
    pavucontrol
    jetbrains-toolbox
    ghostty
    firefox
    spotify
    imv
    nmgui
    code-cursor
    openvpn3
    opencode
    inputs.mcmojave-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.gofi.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.eshot.packages.${pkgs.stdenv.hostPlatform.system}.default
    loupe
    gnome-text-editor
    gns3-gui
    inetutils
    wireshark
    papers
    helix

    zoom-us

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
