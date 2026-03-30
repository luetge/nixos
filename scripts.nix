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
  nixos-isolated = pkgs.writeShellScriptBin "nixos-isolated" ''
    set -e

    VOLUME_NAME="nixos-isolated-nix-store"
    CONTAINER_NAME="nixos-isolated"
    IMAGE="nixos/nix"
    SSH_KEY_1P="op://Private/nix encryption SSH Key/private key"

    usage() {
      echo "Usage: nixos-isolated [--reset] [--shell SHELL] [-- COMMAND...]"
      echo ""
      echo "Run an isolated Nix environment on macOS via Docker."
      echo "Only a single SSH key (from 1Password) is shared. Everything else is isolated."
      echo ""
      echo "Options:"
      echo "  --reset   Remove the persistent nix store volume and start fresh"
      echo "  --shell   Shell to use inside the container (default: bash)"
      echo "  --        Pass remaining arguments as the container command"
      exit 0
    }

    SHELL_CMD="bash"
    EXTRA_CMD=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --help|-h) usage ;;
        --reset)
          echo "Removing persistent nix store volume..."
          ${pkgs.docker}/bin/docker volume rm "$VOLUME_NAME" 2>/dev/null || true
          echo "Done."
          shift
          ;;
        --shell)
          SHELL_CMD="$2"
          shift 2
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

    # Verify docker is available
    if ! ${pkgs.docker}/bin/docker info > /dev/null 2>&1; then
      echo "Error: Docker is not running. Please start Docker Desktop or OrbStack."
      exit 1
    fi

    # Fetch SSH key from 1Password into a temp file
    SSH_TMPDIR=$(mktemp -d)
    trap 'rm -rf "$SSH_TMPDIR"' EXIT
    ${pkgs._1password-cli}/bin/op read "$SSH_KEY_1P" > "$SSH_TMPDIR/id_ed25519"
    chmod 600 "$SSH_TMPDIR/id_ed25519"
    ${pkgs.openssh}/bin/ssh-keygen -y -f "$SSH_TMPDIR/id_ed25519" > "$SSH_TMPDIR/id_ed25519.pub"

    # Create volume for persistent nix store (avoids re-downloading everything)
    ${pkgs.docker}/bin/docker volume create "$VOLUME_NAME" > /dev/null 2>&1 || true

    echo "Starting isolated Nix environment..."
    echo "  Shared: single SSH key from 1Password (read-only)"
    echo "  Persistent: /nix (via Docker volume)"
    echo ""

    COMMAND="''${EXTRA_CMD:-$SHELL_CMD}"

    exec ${pkgs.docker}/bin/docker run \
      -it --rm \
      --name "$CONTAINER_NAME" \
      --hostname nixos-isolated \
      -v "$SSH_TMPDIR/id_ed25519:/root/.ssh/id_ed25519:ro" \
      -v "$SSH_TMPDIR/id_ed25519.pub:/root/.ssh/id_ed25519.pub:ro" \
      -v "$VOLUME_NAME:/nix" \
      -e "NIX_CONFIG=experimental-features = nix-command flakes" \
      "$IMAGE" \
      $COMMAND
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
