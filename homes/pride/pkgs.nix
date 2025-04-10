{
  inputs,
  pkgs,
  ...
}:
let
  zen-browser = inputs.zen-browser.packages."${pkgs.system}".default;
in
{
  home.packages = with pkgs; [
    brave
    mpv
    pavucontrol
    postman
    jetbrains-toolbox
    thunderbird
    ghostty
    firefox
    sublime4

    zathura
    zoom-us
    zen-browser

    devenv
    tokei
    whois
    nixd
    nixfmt-rfc-style

    atool
    axel
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
    zoxide

    (writeShellScriptBin "reload-failed-services" ''
      systemctl --user list-units --failed | grep -Po '([A-Za-z-0-9]+.service)' | xargs systemctl --user restart
    '')

    (writeShellScriptBin "nv" ''
      neovide $@ &
      pid=$!
      disown $pid
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
