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
    kvlibadwaita = {
      url = "github:MOIS3Y/KvLibadwaita"; # or replace to fork owner
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    hyprcursor-phinger.url = "github:jappie3/hyprcursor-phinger";
    hyprcursor.url = "github:hyprwm/hyprcursor";
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      walker,
      # firefox,
      # kvlibadwaita,
      # zen-browser,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          inputs.kvlibadwaita.overlays.default
        ];
      };
    in
    {
      nixosConfigurations = {
        project = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/dell
          ];
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
