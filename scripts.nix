{
  pkgs,
  system,
  darwin,
  user,
}:
let
  ssh-filename = "~/.ssh/id_ed25519_nixos_key";
  sops-age-key-file = "~/.config/sops/age/keys.txt";
  create-age-key = pkgs.writeShellScriptBin "create-age-key" ''
    set -e
    ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i ${ssh-filename} > ${sops-age-key-file}
  '';
  setup-ssh = pkgs.writeShellScriptBin "setup-ssh" ''
    set -e
    if [ ! -f "${ssh-filename}" ]; then
      echo converting and copying ssh key into user .ssh directory
      mkdir -p $HOME/.config/sops/age
      mkdir -p $HOME/.ssh
      rm -f ${ssh-filename}
      ${pkgs._1password-cli}/bin/op read "op://Private/nix encryption SSH Key/private key" > ${ssh-filename}
    fi
    ${create-age-key}/bin/create-age-key
  '';
  fmt-srcs = pkgs.writeShellScriptBin "fmt-srcs" ''
    set -e
    ${pkgs.nixfmt}/bin/nixfmt `find . -type f -name '*.nix'` --check || ${pkgs.nixfmt}/bin/nixfmt `find . -type f -name '*.nix'`
  '';
  edit-secrets = pkgs.writeShellScriptBin "edit-secrets" ''
    set -e
    ${create-age-key}/bin/create-age-key
    echo ${sops-age-key-file}
    SOPS_AGE_KEY_FILE=${sops-age-key-file} ${pkgs.sops}/bin/sops $1
  '';
  rotate-secrets = pkgs.writeShellScriptBin "rotate-secrets" ''
    set -e
    # ${create-age-key}/bin/create-age-key
    echo "Rotating all secrets in secrets/ with keys from .sops.yaml"
    for f in secrets/*; do
      echo "Updating keys for: $f"
      SOPS_AGE_KEY_FILE=${sops-age-key-file} ${pkgs.sops}/bin/sops updatekeys -y "$f"
    done
    echo "Done! All secrets updated with new keys."
  '';
  lima-config = pkgs.writeText "nixos-isolated.yaml" ''
    vmType: vz
    os: Linux
    arch: aarch64
    images:
      - location: https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img
        arch: aarch64
    cpus: 4
    memory: 8GiB
    disk: 50GiB
    # No mounts — full isolation
    mounts: []
    mountType: virtiofs
    networks:
      - vzNAT: true
    provision:
      - mode: system
        script: |
          #!/bin/bash
          set -e
          if ! command -v nix &> /dev/null; then
            curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
            echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
          fi
    rosetta:
      enabled: true
      binfmt: true
  '';
  nixos-isolated = pkgs.writeShellScriptBin "nixos-isolated" ''
    set -e

    VM_NAME="nixos-isolated"
    SSH_KEY_1P="op://Private/nix encryption SSH Key/private key"

    usage() {
      echo "Usage: nixos-isolated [--reset] [-- COMMAND...]"
      echo ""
      echo "Run an isolated Nix environment on macOS via Lima (Virtualization.framework)."
      echo "Only a single SSH key (from 1Password) is injected. Everything else is isolated."
      echo ""
      echo "Options:"
      echo "  --reset   Delete the VM and start fresh"
      echo "  --        Pass remaining arguments as a command to run in the VM"
      exit 0
    }

    EXTRA_CMD=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --help|-h) usage ;;
        --reset)
          echo "Deleting VM..."
          ${pkgs.lima}/bin/limactl delete --force "$VM_NAME" 2>/dev/null || true
          echo "Done."
          shift
          ;;
        --)
          shift
          EXTRA_CMD="$*"
          break
          ;;
        *)
          echo "Unknown option: $1"
          usage
          ;;
      esac
    done

    # Create VM if it doesn't exist
    if ! ${pkgs.lima}/bin/limactl list -q | grep -q "^''${VM_NAME}$"; then
      echo "Creating isolated Nix VM (first run takes a few minutes)..."
      ${pkgs.lima}/bin/limactl create --name "$VM_NAME" ${lima-config}
    fi

    # Start VM if not running
    STATUS=$(${pkgs.lima}/bin/limactl list --json | ${pkgs.jq}/bin/jq -r "select(.name == \"$VM_NAME\") | .status")
    if [ "$STATUS" != "Running" ]; then
      echo "Starting VM..."
      ${pkgs.lima}/bin/limactl start "$VM_NAME"
    fi

    # Inject SSH key from 1Password
    ${pkgs._1password-cli}/bin/op read "$SSH_KEY_1P" | ${pkgs.lima}/bin/limactl shell "$VM_NAME" sh -c 'mkdir -p ~/.ssh && cat > ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519'
    ${pkgs.lima}/bin/limactl shell "$VM_NAME" sh -c 'ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub'

    if [ -n "$EXTRA_CMD" ]; then
      exec ${pkgs.lima}/bin/limactl shell "$VM_NAME" $EXTRA_CMD
    else
      echo ""
      echo "Entering isolated Nix VM..."
      echo "  Shared: single SSH key from 1Password"
      echo "  VM: Lima + Virtualization.framework (VZ)"
      echo ""
      exec ${pkgs.lima}/bin/limactl shell "$VM_NAME"
    fi
  '';
  setup-macos = pkgs.writeShellScriptBin "setup-macos" (
    if pkgs.stdenv.isDarwin then
      ''
        set -e
        # Disable any audio on macOS
        sudo /usr/sbin/nvram SystemAudioVolume=" "

        # Caps lock to ctrl
        hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc": 0x700000039, "HIDKeyboardModifierMappingDst": 0x7000000E0}]}' > /dev/null || true
      ''
    else
      ""
  );
  install = pkgs.writeShellScriptBin "install" (
    if pkgs.stdenv.isDarwin then
      ''
        set -e
        sudo echo "installing system" # make sure we are asked for sudo upfront
        ${setup-ssh}/bin/setup-ssh
        ${setup-macos}/bin/setup-macos
        echo installing system

        # Make space for nix.conf
        sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-install || true
        SUCCESS=0
        function cleanup()
        {
          # Undo move
          if [ $SUCCESS == 1 ]
          then
            # Delete old files
            sudo rm -f /etc/nix/nix.conf.before-install
          else
            # Re-establish old files
            sudo mv /etc/nix/nix.conf.before-install /etc/nix/nix.conf
          fi
        }
        trap cleanup EXIT

        if test -f "./flake.nix"; then
          sudo ${
            darwin.packages.${system}.darwin-rebuild
          }/bin/darwin-rebuild switch --flake .#dlutgehet-work-macbook
        else
          sudo ${
            darwin.packages.${system}.darwin-rebuild
          }/bin/darwin-rebuild switch --flake github:luetge/nixos#dlutgehet-work-macbook
        fi

        SUCCESS=1
      ''
    else
      ""
  );
in
{
  inherit
    install
    fmt-srcs
    edit-secrets
    rotate-secrets
    setup-ssh
    create-age-key
    nixos-isolated
    ;
}
