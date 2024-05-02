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
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };

    package = pkgs.nixVersions.latest;
    registry.nixpkgs.flake = nixpkgs;
    configureBuildUsers = true;

    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = false;
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
      ) "x86_64-darwin aarch64-darwin";
    };
  };
  services.nix-daemon.enable = true;

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
  fonts.fontDir.enable = true;

  home-manager.users.dlutgehet = import ./home.nix;
  home-manager.extraSpecialArgs = {
    inherit user isWorkMachine sops-nix;
    noSystemInstall = false;
  };
}
