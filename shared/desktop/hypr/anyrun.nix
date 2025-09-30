{ inputs, pkgs, ... }:
{
  programs.anyrun = {
    enable = true;
    config = {
      x = {
        fraction = 0.5;
      };
      y = {
        fraction = 0.3;
      };
      width = {
        fraction = 0.3;
      };
      hideIcons = false;
      ignoreExclusiveZones = false;
      layer = "overlay";
      hidePluginInfo = true;
      closeOnClick = true;
      showResultsImmediately = true;
      maxEntries = null;

      plugins = [
      #   inputs.anyrun.packages.${pkgs.system}.applications
      #   inputs.anyrun.packages.${pkgs.system}.stdin
                "${pkgs.anyrun}/lib/libapplications.so"
                "${pkgs.anyrun}/lib/libstdin.so"
      ];
    };

    extraCss = # css
      ''
                #window,
                #match,
                #entry,
                #plugin,
                #main {
                      /* background: transparent; */
                    background: rgba(24, 24, 24, 0.6);
                    }
                #entry {
                    background: rgba(24, 24, 24, 0.6);
                }

        #match:hover {
            background: rgba(82, 167, 246, 0.6);
        }
        #match:selected {
          background: rgba(82, 167, 246, 1);
        }
      '';
  };
}
