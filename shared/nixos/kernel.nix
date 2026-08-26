{
  inputs,
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [
    # Use the exact nixpkgs revision as defined in this repo to ensure binary cache hits.
    inputs.nix-cachyos-kernel.overlays.pinned
  ];
}
