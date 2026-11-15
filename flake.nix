{
  description = "A simple NixOS flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kvlibadwaita = {
      url = "github:MOIS3Y/KvLibadwaita"; # or replace to fork owner
    };
    hyprcursor = {
      url = "github:hyprwm/hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sf-mono-liga-src = {
      url = "github:shaunsingh/SFMono-Nerd-Font-Ligaturized";
      flake = false;
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
    };
    mcmojave-hyprcursor = {
      url = "github:libadoxon/mcmojave-hyprcursor";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
    };
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
  };
  outputs =
    {
      self,
      nixpkgs,
      home-manager,
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

    components = import ./flakes/components {
      inherit pkgs;
      lockWallpaper = ./assets/wallpapers/lock-katana-forest.mp4;
    };
    eshot = import ./flakes/eshot { inherit pkgs; };
    zenbones = import ./flakes/zenbones-mono-flake { inherit pkgs; };

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

    mkHost = name: lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs self; };
      modules = [ ./hosts/${name} ];
    };

    mkHome = modules: home-manager.lib.homeManagerConfiguration {
      inherit pkgs modules;
      extraSpecialArgs = {
        inherit inputs self components eshot zenbones;
      };
    };
  in
  {
    nixosConfigurations.bystial = mkHost "bystial";

    homeConfigurations.pride = mkHome [
      inputs.stylix.homeModules.stylix
      ./homes/pride
    ];

    formatter = forEachSupportedSystem ({ pkgs }: pkgs.nixfmt);

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

    checks = {
      x86_64-linux = {
        inherit (components.checks.x86_64-linux) qmllint;
      };
    };

    packages = {
      x86_64-linux = {
        default = components.packages.x86_64-linux.qs-shell;
        qs-shell = components.packages.x86_64-linux.qs-shell;
        qs-lock = components.packages.x86_64-linux.qs-lock;
        shell-agents = components.packages.x86_64-linux.shell-agents;
        eshot = eshot.packages.x86_64-linux.default;
        inherit (zenbones.packages.x86_64-linux) zenbones-mono zenbones-brainy zenbones-prose zenbones-proto zenbones-slab;
      };
    };
  };
}
