{
  description = "A simple NixOS flake";
  nixConfig = {
    extra-substituters = [
      "https://colmena.cachix.org"
      "https://vicinae.cachix.org"
    ];
    extra-trusted-public-keys = [
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    ];
  };
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kvlibadwaita = {
      url = "github:MOIS3Y/KvLibadwaita"; # or replace to fork owner
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprcursor.url = "github:hyprwm/hyprcursor";
    sf-mono-liga-src = {
      url = "github:shaunsingh/SFMono-Nerd-Font-Ligaturized";
      flake = false;
    };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    zenbones.url = "./flakes/zenbones-mono-flake";
    mcmojave-hyprcursor.url = "github:libadoxon/mcmojave-hyprcursor";
    vicinae.url = "github:vicinaehq/vicinae"; # tell Nixos where to get Vicinae
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      vicinae,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          inputs.neovim-nightly-overlay.overlays.default
          inputs.kvlibadwaita.overlays.default
          (final: prev: {
            sf-mono-liga-bin = prev.stdenvNoCC.mkDerivation {
              pname = "sf-mono-liga-bin";
              version = "dev";
              src = inputs.sf-mono-liga-src;
              dontConfigure = true;
              installPhase = ''
                mkdir -p $out/share/fonts/opentype
                cp -R $src/*.otf $out/share/fonts/opentype/
              '';
            };
          })
        ];
      };

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import nixpkgs { inherit system; };
          }
        );

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
        bystial = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/bystial
          ];
        };
      };

      homeConfigurations = {
        pride = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            vicinae.homeManagerModules.default
            ./homes/pride
          ];

          extraSpecialArgs = {
            inherit inputs;
          };
        };
        lubellion = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./homes/lubellion
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };
      };

      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixd
              nixfmt
            ];
          };
        }
      );
    };
}
