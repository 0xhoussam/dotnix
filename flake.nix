{
  description = "A simple NixOS flake";
  nixConfig = {
    extra-substituters = [
      "https://colmena.cachix.org"
      "https://anyrun.cachix.org"
    ];
    extra-trusted-public-keys = [
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    ];
  };
  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kvlibadwaita = {
      url = "github:MOIS3Y/KvLibadwaita"; # or replace to fork owner
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    hyprcursor-phinger.url = "github:jappie3/hyprcursor-phinger";
    hyprcursor.url = "github:hyprwm/hyprcursor";
    sf-mono-liga-src = {
      url = "github:shaunsingh/SFMono-Nerd-Font-Ligaturized";
      flake = false;
    };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    anyrun.url = "github:anyrun-org/anyrun";
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      anyrun,
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
      };

      homeConfigurations = {
        pride = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./homes/pride
            anyrun.homeManagerModules.default
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
              nixfmt-rfc-style
            ];
          };
        }
      );
    };
}
