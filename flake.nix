{
  description = "Daniel's systems";

  inputs = {
    # Package sets
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05-small";

    # Environment/system management
    darwin.url = "github:lnl7/nix-darwin/nix-darwin-25.05";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Other sources
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      darwin,
      home-manager,
      flake-utils,
      sops-nix,
      pre-commit-hooks,
    }@inputs:
    let
      inherit (darwin.lib) darwinSystem;
      user = "dlutgehet";
      darwinConfigurations = {
        dlutgehet-work-macbook =
          let
            system = "aarch64-darwin";
          in
          darwinSystem {
            inherit system;
            modules = [
              ./machines/macbook_work/configuration.nix
              home-manager.darwinModules.home-manager
            ];
            specialArgs = {
              inherit
                darwin
                nixpkgs
                self
                user
                sops-nix
                ;
            };
          };
      };
    in
    {
      inherit darwinConfigurations;

      #nixosConfigurations.rbpi = nixpkgs.lib.nixosSystem {
      #  system = "aarch64-linux";
      #  specialArgs = {
      #    rev = if (self ? rev) then self.rev else null;
      #  } // inputs;
      #  modules = [ ./machines/rbpi/configuration.nix ];
      #};
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        scripts = (import ./scripts.nix) {
          inherit
            pkgs
            darwin
            system
            user
            ;
        };
        # Define git hooks that get automatically installed
        git-hooks = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            format_all = {
              enable = true;
              name = "fmt";
              entry = "${scripts.fmt-srcs}/bin/fmt-srcs";
              pass_filenames = false;
            };
          };
        };
        dlutgehet-home-config = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [ ./common/home.nix ];
          extraSpecialArgs = {
            inherit user sops-nix inputs;
            isWorkMachine = true;
            noSystemInstall = true;
          };
        };
      in
      {
        homeConfigurations.dlutgehet = dlutgehet-home-config;
        packages = {
          inherit git-hooks;
          dlutgehet-work-macbook-cache = dlutgehet-home-config.activationPackage; # TODO: Fix and replace by darwinConfigurations.dlutgehet-work-macbook.system
          default = scripts.install;
        }
        // scripts;
        checks = {
          inherit git-hooks;
        };
        devShells.default = pkgs.mkShell {
          buildInputs = pkgs.lib.attrValues scripts;

          inherit (git-hooks) shellHook;
        };
      }
    );
}
