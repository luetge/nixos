{
  description = "Daniel's systems";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };

    # Other sources
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, darwin, home-manager, flake-utils, sops-nix
    , pre-commit-hooks }:
    let
      inherit (darwin.lib) darwinSystem;
      user = "dlutgehet";
    in {

      #nixosConfigurations.rbpi = nixpkgs.lib.nixosSystem {
      #  system = "aarch64-linux";
      #  specialArgs = {
      #    rev = if (self ? rev) then self.rev else null;
      #  } // inputs;
      #  modules = [ ./machines/rbpi/configuration.nix ];
      #};

      darwinConfigurations = {
        dlutgehet-work-macbook = let system = "aarch64-darwin";
        in darwinSystem {
          inherit system;
          modules = [
            ./machines/macbook_work/configuration.nix
            home-manager.darwinModules.home-manager
          ];
          specialArgs = { inherit darwin nixpkgs self user sops-nix; };
        };
      };

    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        scripts = (import ./scripts.nix) { inherit pkgs darwin system user; };
        # Define git hooks that get automatically installed
        git-hooks = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            format_all = {
              enable = true;
              name = "fmt";
              entry = "${scripts.fmt}/bin/fmt";
              pass_filenames = false;
            };
          };
        };

      in {
        packages = {
          inherit git-hooks;
          default = scripts.install;
          homeConfigurations.dlutgehet =
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;

              modules = [ ./common/home.nix ];
              extraSpecialArgs = {
                inherit user sops-nix;
                isWorkMachine = true;
                noSystemInstall = true;
              };
            };
        } // scripts;
        checks = { inherit git-hooks; };
        devShells.default = pkgs.mkShell {
          buildInputs = pkgs.lib.attrValues scripts;

          inherit (git-hooks) shellHook;
        };
      });
}
