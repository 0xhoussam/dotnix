# The desktop's colour palette: Carbonfox, the theme the terminal uses
# (ghostty, shared/home-manager/gui/ghostty.nix), as a base16 scheme.
# Carbonfox has no real yellow or orange (its "yellow" is teal), so those two
# slots use IBM Carbon's, to keep warnings readable.
#
# Imported by Stylix (homes/pride/stylix.nix) and by the NixOS side, which has
# no Stylix (hosts/bystial/brave.nix writes Brave's theme colour from it).
{
  scheme = "Carbonfox";
  author = "EdenEast/nightfox.nvim, IBM Carbon";
  base00 = "161616"; # window background
  base01 = "252525"; # popovers, raised surfaces
  base02 = "2a2a2a"; # selection
  base03 = "7b7c7e"; # comments, muted
  base04 = "a9afbc"; # dim text
  base05 = "f2f4f8"; # text
  base06 = "f2f4f8";
  base07 = "ffffff";
  base08 = "ee5396"; # red
  base09 = "ff832b"; # orange (Carbon)
  base0A = "f1c21b"; # yellow (Carbon)
  base0B = "25be6a"; # green
  base0C = "33b1ff"; # cyan
  base0D = "78a9ff"; # blue (accent)
  base0E = "be95ff"; # purple
  base0F = "ff7eb6"; # pink
}
