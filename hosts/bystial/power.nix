{ pkgs, ... }: {
  boot.kernelParams = [
    "iwlwifi.power_save=true"
    "iwlwifi.power_level=5"
    "iwlmvm.power_scheme=3"
  ];

  services.thermald.enable = true;

  services.power-profiles-daemon.enable = false;

  services.tuned = {
    enable = true;
    ppdSupport = false;
    recommend = { };
    settings = {
      daemon = true;
      dynamic_tuning = true;
      sleep_interval = 1;
      update_interval = 10;
    };
    profiles = {
      laptop-ac-balanced = {
        main = {
          summary = "Balanced profile for laptop on AC power with Intel optimizations";
          include = "balanced";
        };
        cpu = {
          governor = "schedutil|conservative|powersave";
          energy_perf_bias = "performance|normal";
          energy_performance_preference = "balance_performance";
          boost = 1;
        };
        acpi = {
          platform_profile = "balanced";
        };
        audio = {
          timeout = 10;
        };
        video = {
          panel_power_savings = 1;
        };
        scsi_host = {
          alpm = "med_power_with_dipm";
        };
      };

      laptop-battery-maxpower = {
        main = {
          summary = "Maximum power saving profile for laptop battery mode";
          include = "powersave";
        };
        cpu = {
          governor = "powersave";
          energy_perf_bias = "power";
          energy_performance_preference = "power";
          boost = 0;
        };
        usb = {
          autosuspend = 1;
        };
        acpi = {
          platform_profile = "low-power";
        };
        audio = {
          timeout = 10;
        };
        scsi_host = {
          alpm = "med_power_with_dipm";
        };
        sysctl = {
          type = "sysctl";
          "vm.laptop_mode" = 1;
          "kernel.nmi_watchdog" = 0;
          "vm.dirty_expire_centisecs" = 6000;
          "vm.dirty_writeback_centisecs" = 6000;
        };
      };
    };
  };

  services.acpid = {
    enable = true;
    logEvents = true;
    acEventCommands = ''
      vals=($1)
      case ''${vals[3]} in
        00000000)
          ${pkgs.tuned}/bin/tuned-adm profile laptop-battery-maxpower
          ${pkgs.sudo}/bin/sudo -u pride ${pkgs.hyprland}/bin/hyprctl keyword animations:enabled false || true
          ;;
        00000001)
          ${pkgs.tuned}/bin/tuned-adm profile laptop-ac-balanced
          ${pkgs.sudo}/bin/sudo -u pride ${pkgs.hyprland}/bin/hyprctl keyword animations:enabled true || true
          ;;
        *)
          echo "acpid: unknown AC state: ''${vals[3]}" | systemd-cat -t acpid-tuned -p warning
          ;;
      esac
    '';
  };

  systemd.services.tuned-boot-profile = {
    description = "Set tuned profile based on power state at boot";
    after = [ "tuned.service" ];
    wants = [ "tuned.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      AC_PATH="/sys/class/power_supply/AC/online"
      if [ -f "$AC_PATH" ] && [ "$(cat "$AC_PATH")" = "1" ]; then
        ${pkgs.tuned}/bin/tuned-adm profile laptop-ac-balanced
        ${pkgs.sudo}/bin/sudo -u pride ${pkgs.hyprland}/bin/hyprctl keyword animations:enabled true || true
      else
        ${pkgs.tuned}/bin/tuned-adm profile laptop-battery-maxpower
        ${pkgs.sudo}/bin/sudo -u pride ${pkgs.hyprland}/bin/hyprctl keyword animations:enabled false || true
      fi
    '';
  };

  powerManagement = {
    enable = true;
  };
}
