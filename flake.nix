{
  description = "A simple NixOS flake";
  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    walker.url = "github:abenz1267/walker";
    swww.url = "github:LGFae/swww";
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-flatpak,
      walker,
      swww,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations = {
        project = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [ ./hosts/dell ];
        };
      };

      homeConfigurations = {
        pride = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            nix-flatpak.homeManagerModules.nix-flatpak
            walker.homeManagerModules.default
            ./homes/pride
          ];

          extraSpecialArgs = {
            inherit inputs system;
          };
        };
      };
    };
}
