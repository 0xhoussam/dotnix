{ config, pkgs, inputs, self, ... }:
let
  palette = import ../../shared/theme/carbonfox.nix;
  lock = self.packages.${pkgs.stdenv.hostPlatform.system}.qs-lock;
  user = "pride";

  sfPro = inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro-nerd;
  sfMono = pkgs.runCommand "sf-mono-liga" { } ''
    mkdir -p $out/share/fonts/opentype
    cp ${inputs.sf-mono-liga-src}/*.otf $out/share/fonts/opentype/
  '';

  # What the lock screen reads from ~/.config/my-shell/stylix.json (written by
  # Home Manager from Stylix). The greeter user has no home, so the same file
  # is built here from the same palette, in a config dir the greeter points at.
  themeDir = pkgs.writeTextDir "my-shell/stylix.json" (builtins.toJSON {
    polarity = "dark";
    font.sans = "SFProDisplay Nerd Font";
    colors = builtins.removeAttrs palette [ "scheme" "author" ];
  });

  # The greeter user has none of the fonts Home Manager installs for pride.
  fonts = pkgs.writeText "greeter-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${pkgs.orbitron}/share/fonts</dir>
      <dir>${sfPro}/share/fonts</dir>
      <dir>${sfMono}/share/fonts</dir>
      <cachedir>/var/cache/greeter-fontconfig</cachedir>
    </fontconfig>
  '';

  # The login screen is the lock screen (pkgs/desktop-shell/lockscreen) in
  # GREETER mode: a fullscreen window in cage, auth through greetd. It runs the
  # stored build (the greeter user cannot read the checkout).
  session = pkgs.writeShellScript "greeter-session" ''
    export GREETER=1 GREETER_USER=${user} USER=${user}
    # Same layout as Hyprland (cage has no config of its own).
    export XKB_DEFAULT_LAYOUT=${config.services.xserver.xkb.layout}
    export XKB_DEFAULT_VARIANT=${config.services.xserver.xkb.variant}
    export XDG_CACHE_HOME=/var/cache/greeter-state
    export XDG_CONFIG_HOME=${themeDir}
    export XDG_STATE_HOME=/var/cache/greeter-state
    export FONTCONFIG_FILE=${fonts}
    export QT_QPA_PLATFORM=wayland
    # If the greeter dies (QML error, cage failure) fall back to tuigreet so
    # login never depends on this working.
    ${pkgs.cage}/bin/cage -s -m last -- ${lock}/bin/lock-screen-store \
      || exec ${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland
  '';
in
{
  services.greetd = {
    enable = true;
    settings.default_session.command = "${session}";
  };

  # `greeter` needs somewhere writable for the font cache.
  systemd.tmpfiles.rules = [ "d /var/cache/greeter-fontconfig 0755 greeter greeter -" "d /var/cache/greeter-state 0755 greeter greeter -" ];
}
