{
  description = "A simple NixOS flake";
  nixConfig = {
    extra-substituters = [
      "https://cache.xinux.uz"
    ];
    extra-trusted-public-keys = [
      "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
    ];
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
    };
    kvlibadwaita = {
      url = "github:MOIS3Y/KvLibadwaita"; # or replace to fork owner
    };
    hyprcursor = {
      url = "github:hyprwm/hyprcursor";
    };
    sf-mono-liga-src = {
      url = "github:shaunsingh/SFMono-Nerd-Font-Ligaturized";
      flake = false;
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
    };
    zenbones.url = "./flakes/zenbones-mono-flake";
    mcmojave-hyprcursor = {
      url = "github:libadoxon/mcmojave-hyprcursor";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
    };
    components = {
      url = "./flakes/components"; # AGS bar (vendored)
    };
    gofi = {
      url = "./flakes/gofi";
    };
    eshot = {
      url = "./flakes/eshot";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };
   outputs =
     {
       self,
       nixpkgs,
       home-manager,
       gofi,
       ...
     }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
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
            inherit inputs self;
          };
          modules = [
            ./hosts/dell
          ];
        };
        bystial = lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs self;
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
            ./homes/pride
          ];
          extraSpecialArgs = {
            inherit inputs self;
          };
        };
        lubellion = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./homes/lubellion
          ];
          extraSpecialArgs = {
            inherit inputs self;
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
