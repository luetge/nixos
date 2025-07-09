{
  lib,
  pkgs,
  nixpkgs,
  user,
  isWorkMachine,
  sops-nix,
  ...
}:
{

  # System packages
  environment = {
    systemPackages = [ ];
    pathsToLink = [
      "/share/nix-direnv"
      "/share/zsh"
    ];
  };

  nix = {
    enable = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 15d";
      interval = {
        Weekday = 0;
        Hour = 0;
        Minute = 0;
      };
    };

    linux-builder = {
      enable = true;
      ephemeral = true;
      maxJobs = 4;
      config = {
        virtualisation = {
          darwin-builder = {
            diskSize = 40 * 1024;
            memorySize = 8 * 1024;
          };
          cores = 6;
        };
      };
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };

    nixPath = [ "nixpkgs=${nixpkgs}" ];

    package = pkgs.nixVersions.latest;
    optimise.automatic = true;

    settings = {
      experimental-features = "nix-command flakes";
      keep-outputs = true;
      keep-derivations = true;
      warn-dirty = false;
      build-users-group = "nixbld";
      builders-use-substitutes = true;
      allow-import-from-derivation = true;
      http-connections = 128;
      max-substitution-jobs = 128;
      trusted-users = [
        "@admin"
        user
      ];
      substituters = [
        "https://cache.nixos.org/"
        "https://cache.garnix.io"
      ];
      trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
      system-features = [
        "kvm"
        "nixos-test"
        "benchmark"
        "big-parallel"
        "hvf"
      ];
      extra-platforms = lib.optionalString (
        pkgs.system == "aarch64-darwin"
      ) "x86_64-darwin x86_64-linux aarch64-darwin";
    };
  };

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ (self: super: { nix-direnv = super.nix-direnv.override { enableFlakes = true; }; }) ];
  };
  system.stateVersion = 4;
  programs = {
    nix-index.enable = true;
    zsh.enable = true;
  };

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  home-manager.users.dlutgehet = import ./home.nix;
  home-manager.extraSpecialArgs = {
    inherit user isWorkMachine sops-nix;
    noSystemInstall = false;
  };
}
