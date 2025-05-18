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
    etc."nix/nix.custom.conf".text = pkgs.lib.mkForce ''
      allow-import-from-derivation = true
      allowed-users = *
      auto-optimise-store = false
      build-users-group = nixbld
      builders-use-substitutes = true
      cores = 0
      experimental-features = nix-command flakes
      http-connections = 128
      keep-derivations = true
      keep-outputs = true
      max-jobs = auto
      max-substitution-jobs = 128
      require-sigs = true
      sandbox = false
      sandbox-fallback = false
      substituters = https://cache.nixos.org/ https://cache.garnix.io https://cache.nixos.org/
      system-features = kvm nixos-test benchmark big-parallel hvf
      trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      trusted-substituters =
      trusted-users = @admin dlutgehet root
      warn-dirty = false
      extra-platforms = x86_64-darwin aarch64-darwin
      extra-sandbox-paths =
      lazy-trees = true
    '';
  };

  nix.enable = false;

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
