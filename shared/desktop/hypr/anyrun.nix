{ inputs, pkgs, ... }:
{
  programs.anyrun = {
    enable = true;
    # package = inputs.anyrun.packages.${pkgs.system}.anyrun-with-all-plugins;
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
      #   # An array of all the plugins you want, which either can be paths to the .so files, or their packages
      #   inputs.anyrun.packages.${pkgs.system}.applications
      #   inputs.anyrun.packages.${pkgs.system}.stdin
                "${pkgs.anyrun}/lib/libapplications.so"
                "${pkgs.anyrun}/lib/libstdin.so"
      ];
    };

    # Inline comments are supported for language injection into
    # multi-line strings with Treesitter! (Depends on your editor)
    extraCss = # css
      ''
                #window,
                #match,
                #entry,
                #plugin,
                #main {
                      /* background: transparent; */
                    background: rgba(24, 24, 24, 0.8);
                    }
                #entry {
                    background: rgba(24, 24, 24, 0.8);
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
