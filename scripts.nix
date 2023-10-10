{ pkgs, system, darwin, user }:
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
      ${pkgs._1password}/bin/op read "op://Private/nix encryption SSH Key/private key" > ${ssh-filename}
    fi
    ${create-age-key}/bin/create-age-key
  '';
  fmt = pkgs.writeShellScriptBin "fmt" ''
    set -e
    ${pkgs.nixfmt}/bin/nixfmt `find . -type f -name '*.nix'` --check || ${pkgs.nixfmt}/bin/nixfmt `find . -type f -name '*.nix'`
  '';
  edit-secrets = pkgs.writeShellScriptBin "edit-secrets" ''
    set -e
    ${create-age-key}/bin/create-age-key
    echo ${sops-age-key-file}
    SOPS_AGE_KEY_FILE=${sops-age-key-file} ${pkgs.sops}/bin/sops $1
  '';
  setup-macos-dock = let
    to_dock_entry = path:
      "'<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://${
        toString path
      }</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>' ";
    dock-entries = pkgs.lib.strings.concatMapStrings to_dock_entry [
      "/Applications/Microsoft%20Outlook.app/"
      "/Users/${user}/.nix-profile/Applications/kitty.app/"
      "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/"
      "/Applications/Slack.app/"
      "/System/Applications/Music.app/"
    ];
  in pkgs.writeShellScriptBin "setup-macos-dock" ''
    set -e
    # TODO: Make it configuration once https://github.com/LnL7/nix-darwin/pull/619 gets merged
    defaults write com.apple.dock persistent-apps -array ${dock-entries}
    killall Dock
  '';
  setup-macos = pkgs.writeShellScriptBin "setup-macos"
    (if pkgs.stdenv.isDarwin then ''
      set -e
      # Disable any audio on macOS
      sudo nvram SystemAudioVolume=" "

      # Caps lock to ctrl
      hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc": 0x700000039, "HIDKeyboardModifierMappingDst": 0x7000000E0}]}' > /dev/null || true

      ${setup-macos-dock}/bin/setup-macos-dock
    '' else
      "");
  install = pkgs.writeShellScriptBin "install" ''
    set -e
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
      ${
        darwin.packages.${system}.darwin-rebuild
      }/bin/darwin-rebuild switch --flake .#dlutgehet-work-macbook
    else
      ${
        darwin.packages.${system}.darwin-rebuild
      }/bin/darwin-rebuild switch --flake github:luetge/nixos#dlutgehet-work-macbook
    fi

    SUCCESS=1
  '';

in { inherit install fmt edit-secrets setup-macos-dock; }
