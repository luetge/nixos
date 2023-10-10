{ rev ? null, pkgs, nixpkgs, home-manager, user, lib, sops-nix, ... }:
let
  base = (import ../../common/base.nix) {
    inherit lib pkgs nixpkgs user sops-nix;
    isWorkMachine = false;
  };
in base // {
  system.configurationRevision = pkgs.lib.mkIf (rev != null) rev;

  imports = [ home-manager.nixosModule ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "cma=256M" ];

    loader = {
      grub.enable = false;
      raspberryPi = {
        enable = true;
        version = 4;
      };
    };
    cleanTmpDir = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  swapDevices = [{
    device = "/swapfile";
    size = 1024;
  }];

  networking.hostName = "rbpi";

  # Preserve space by disabling documentation and enaudo ling
  # automatic garbage collection
  documentation.nixos.enable = false;

  # Configure SSH
  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
  };

  # Add users
  users.users = {
    root = { };
    dlutgehet = {
      isNormalUser = true;
      home = "/home/${user}";
      extraGroups = [ "wheel" ];
    };
  };
}
