{
  rev ? null,
  pkgs,
  home-manager,
  user,
  ...
}:
{
  # NOTE: common/base.nix is darwin-only (linux-builder, system.keyboard, …);
  # this NixOS config stands alone until a cross-platform base is split out.
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

  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
    }
  ];

  networking.hostName = "rbpi";

  # Preserve space by disabling documentation and enaudo ling
  # automatic garbage collection
  documentation.nixos.enable = false;

  # Configure SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
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
