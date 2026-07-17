{ pkgs, ... }: {
  boot.kernelParams = [
    "iwlwifi.power_save=true"
    "iwlwifi.power_level=5"
    "iwlmvm.power_scheme=3"
  ];

  services.thermald = {
    enable = true;
  };

  services.power-profiles-daemon.enable = false;

  services.tuned = {
    enable = true;
  };

  services.acpid = {
    enable = true;
    logEvents = true;
    acEventCommands = ''
      vals=($1)
      case ''${vals[3]} in
        00000000)
          ${pkgs.tuned}/bin/tuned-adm profile laptop-battery-powersave
          ;;
        00000001)
          ${pkgs.tuned}/bin/tuned-adm profile balanced
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
        ${pkgs.tuned}/bin/tuned-adm profile balanced
      else
        ${pkgs.tuned}/bin/tuned-adm profile laptop-battery-powersave
      fi
    '';
  };

}
