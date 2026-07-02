{
  description = "Daniel's systems";

  inputs = {
    # Package sets
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Environment/system management
    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Always-fresh Claude Code (nixpkgs lags behind upstream releases)
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
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
      nixpkgs-unstable,
      darwin,
      home-manager,
      flake-utils,
      sops-nix,
      pre-commit-hooks,
      claude-code-nix,
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
              {
                nixpkgs.overlays = [
                  claude-code-nix.overlays.default
                  (_final: _prev: {
                    mas = (import nixpkgs-unstable { inherit system; }).mas;
                  })
                ];
              }
              sops-nix.darwinModules.sops
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
          overlays = [ claude-code-nix.overlays.default ];
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
            nixfmt-rfc-style.enable = true;
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
        # Standalone home-manager config for non-managed (e.g. remote) systems.
        homeConfigurations.dlutgehet = dlutgehet-home-config;
        # `nix fmt` formats the whole tree with nixfmt
        formatter = pkgs.nixfmt-tree;
        packages = {
          inherit git-hooks;
          default = scripts.install;
        }
        // scripts
        # Expose the full system closure so CI can build/cache it.
        // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
          dlutgehet-work-macbook-cache = darwinConfigurations.dlutgehet-work-macbook.system;
        };
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
