{
  description = "A simple NixOS flake";
  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker.url = "github:abenz1267/walker";
    firefox = {
      url = "github:nix-community/flake-firefox-nightly";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      walker,
      disko,
      firefox,
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
            walker.homeManagerModules.default
            ./homes/pride
          ];

          extraSpecialArgs = {
            inherit inputs;
          };
        };
      };
    };
}
