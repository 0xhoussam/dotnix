{ ... }:
let
  palette = import ../../shared/theme/carbonfox.nix;
in
{
  # Brave has no Stylix target, and Chromium reads managed policies only from
  # /etc, which Home Manager cannot write. So the NixOS side sets the browser
  # frame colour and dark scheme from the same palette Stylix uses
  # (shared/theme/carbonfox.nix). Websites keep their own colours.
  environment.etc."brave/policies/managed/theme.json".text = builtins.toJSON {
    BrowserThemeColor = "#${palette.base00}";
    BrowserColorScheme = "dark";
  };
}
