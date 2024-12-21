{
  description = "A simple NixOS flake";
  nixConfig = {
    extra-substituters = [
      "https://colmena.cachix.org"
    ];
    extra-trusted-public-keys = [
      "colmena.cachix.org-1:7BzpDnjjH8ki2CT3f6GdOk7QAzPOl+1t3LvTLXqYcSg="
    ];
  };
  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    walker.url = "github:abenz1267/walker";
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
    ags.url = "github:Aylur/ags";
    wezterm.url = "github:wez/wezterm?dir=nix";
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      walker,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          inputs.kvlibadwaita.overlays.default
          (final: prev: {
            sf-mono-liga-bin = prev.stdenvNoCC.mkDerivation rec {
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
            walker.homeManagerModules.default
            ./homes/pride
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
