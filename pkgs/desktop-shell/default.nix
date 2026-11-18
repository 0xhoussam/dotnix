{
  pkgs,
  # video (or image) for the lock screen background; null = dark gradient
  lockWallpaper ? null,
  ...
}:
let
  system = "x86_64-linux";
  # HUD font for the lock screen, added on top of the system fontconfig.
  lockFonts = pkgs.writeText "lock-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <dir>${pkgs.orbitron}/share/fonts</dir>
    </fontconfig>
  '';

  # Programs the Quickshell shell runs. A systemd user unit has a short PATH
  # (no /run/current-system/sw/bin), so they are put on the wrapper's PATH.
  shellTools = pkgs.lib.makeBinPath (with pkgs; [
    brightnessctl cliphist wl-clipboard wireplumber pipewire tuned util-linux systemd
    xdg-utils pavucontrol networkmanagerapplet libnotify procps coreutils bash
    wf-recorder tesseract hyprland curl wtype
  ]);

  # D-Bus agents for the Quickshell bar (BlueZ pairing, later OBEX and the
  # NetworkManager secret agent). Pure-Rust D-Bus: no libnm/libsecret.
  shellAgents = pkgs.rustPlatform.buildRustPackage {
    pname = "shell-agents";
    version = "0.1.0";
    src = ./agents;
    cargoLock.lockFile = ./agents/Cargo.lock;
  };
in {
  packages.${system} = rec {
    shell-agents = shellAgents;
    default = qs-shell;
    qs-lock = pkgs.stdenvNoCC.mkDerivation {
      name = "qs-lock";
      src = ./lockscreen;
      nativeBuildInputs = [pkgs.makeWrapper];
      dontBuild = true;
      # Three programs in $out/bin:
      #  lock-screen        what everything calls. Runs the live checkout when
      #                     ~/.config/quickshell/my-lock exists (Home Manager
      #                     symlinks it to the checkout, like the bar), so QML
      #                     edits apply without a rebuild. If that dies within
      #                     a few seconds (a QML error) it falls back to the
      #                     stored build, so a broken edit cannot leave the
      #                     session without a lock.
      #  lock-screen-live   quickshell -c my-lock (the checkout).
      #  lock-screen-store  quickshell on the copy in the Nix store.
      # -n: a second launch exits instead of locking twice.
      # --set-default so `LOCK_WALLPAPER=... lock-screen` can still override it.
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/qs-lock $out/bin
        cp -r . $out/share/qs-lock

        mkWrapper() {
          makeWrapper ${pkgs.quickshell}/bin/qs "$1" \
            --add-flags "-n $2" \
            --set-default FONTCONFIG_FILE ${lockFonts} \
            --prefix PATH : ${shellTools} \
            --prefix NIXPKGS_QT6_QML_IMPORT_PATH : ${pkgs.qt6.qtmultimedia}/lib/qt-6/qml \
            --prefix QT_PLUGIN_PATH : ${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins${
          pkgs.lib.optionalString (lockWallpaper != null) " \\\n            --set-default LOCK_WALLPAPER ${lockWallpaper}"
        }
        }
        mkWrapper $out/bin/lock-screen-store "-p $out/share/qs-lock"
        mkWrapper $out/bin/lock-screen-live "-c my-lock"

        cat > $out/bin/lock-screen <<'EOF'
        #!@bash@
        cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/my-lock"
        if [ -f "$cfg/shell.qml" ]; then
          start=$SECONDS
          @out@/bin/lock-screen-live "$@"
          code=$?
          if [ "$code" -eq 0 ] || [ $((SECONDS - start)) -ge 3 ]; then exit "$code"; fi
          echo "lock-screen: live config exited $code after $((SECONDS - start))s, using the stored build" >&2
        fi
        exec @out@/bin/lock-screen-store "$@"
        EOF
        substituteInPlace $out/bin/lock-screen --replace-fail @out@ $out --replace-fail @bash@ ${pkgs.bash}/bin/bash
        chmod +x $out/bin/lock-screen
        runHook postInstall
      '';
    };

    qs-shell = pkgs.stdenvNoCC.mkDerivation {
      name = "qs-shell";
      src = ./shell;
      # for the user service, which runs the live checkout (shared/desktop/shell/shell.nix)
      passthru = { inherit shellTools shellAgents; lock = qs-lock; };
      nativeBuildInputs = [pkgs.makeWrapper];
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/qs-shell $out/bin
        cp -r . $out/share/qs-shell
        makeWrapper ${pkgs.quickshell}/bin/qs $out/bin/my-shell \
          --add-flags "-p $out/share/qs-shell" \
          --prefix XDG_DATA_DIRS : ${pkgs.adwaita-icon-theme}/share \
          --prefix PATH : ${shellTools} \
          --suffix PATH : /run/current-system/sw/bin \
          --set-default QS_ICON_THEME Adwaita \
          --set-default SHELL_AGENTS ${shellAgents}/bin/shell-agents \
          --set-default SHELL_LOCK_CMD ${qs-lock}/bin/lock-screen
        # `shell-ctl toggle volume`, `shell-ctl osd brightness`, ... (IpcHandler "shell")
        makeWrapper ${pkgs.quickshell}/bin/qs $out/bin/shell-ctl \
          --add-flags "ipc --path $out/share/qs-shell call"
        runHook postInstall
      '';
    };
  };

  # qmllint over the Quickshell configs. Warnings are reported, not fatal
  # (yet): see result/report.txt.
  checks.${system}.qmllint = pkgs.runCommand "qmllint" {nativeBuildInputs = [pkgs.qt6.qtdeclarative];} ''
    mkdir -p $out
    cp -r ${./shell} shell
    cp -r ${./lockscreen} lockscreen
    chmod -R u+w shell lockscreen
    find shell lockscreen -name '*.qml' | sort | xargs qmllint \
      -I ${pkgs.quickshell}/lib/qt-6/qml -I ${pkgs.qt6.qtmultimedia}/lib/qt-6/qml \
      -I shell -I lockscreen > $out/report.txt 2>&1 || true
    echo "qmllint: $(grep -c -E '^(Warning|Error)' $out/report.txt || true) findings"
  '';

  devShells.${system} = {
    default = pkgs.mkShell {
      buildInputs = [
        pkgs.quickshell
        pkgs.kdePackages.qtdeclarative # qmlls, qmllint
      ];
    };
  };
}