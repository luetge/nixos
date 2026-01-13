{
  lib,
  pkgs,
  nixpkgs,
  user,
  sops-nix,
  config,
  ...
}:
let
  base = (import ../../common/base.nix) {
    inherit
      lib
      pkgs
      nixpkgs
      user
      sops-nix
      config
      ;
    isWorkMachine = true;
  };
  hostName = "${user}-work-macbook";
  system-update = pkgs.writeShellScriptBin "system-update" (
    if pkgs.stdenv.isDarwin then
      ''
        sudo determinate-nixd upgrade
        sudo darwin-rebuild switch --flake github:luetge/nixos
      ''
    else
      ''exit "not implemented yet"''
  );
in
base
// {
  networking = {
    knownNetworkServices = [
      "Wi-Fi"
      "Bluetooth PAN"
      "Thunderbolt Bridge"
      "VPN"
    ];
    hostName = hostName;
    computerName = hostName;
    localHostName = hostName;
  };

  ids.gids.nixbld = 350;

  nixpkgs = {
    hostPlatform = "aarch64-darwin";
  };

  determinate-nix.customSettings = {
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
      "root"
      user
    ];
    allowed-users = [
      "@admin"
      "root"
      user
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://cache.garnix.io"
    ];
    trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    system-features = [
      "kvm"
      "nixos-test"
      "benchmark"
      "big-parallel"
      "hvf"
    ];
    extra-platforms = lib.optionalString (
      pkgs.stdenv.hostPlatform.system == "aarch64-darwin"
    ) "x86_64-darwin x86_64-linux aarch64-darwin";
  };

  system.stateVersion = 5;

  system.primaryUser = user;

  environment = base.environment // {
    systemPackages = base.environment.systemPackages ++ [ system-update ];
  };

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  system.defaults = {
    dock = {
      autohide = true;
      orientation = "right";
      autohide-delay = 0.0;
      autohide-time-modifier = 0.2;
      mru-spaces = false;
      show-recents = false;
      expose-animation-duration = 0.2;
      tilesize = 48;
      launchanim = false;
      static-only = false;
      showhidden = true;
      show-process-indicators = true;
      wvous-bl-corner = 2; # Mission control
      wvous-br-corner = null; # Nothing
      wvous-tr-corner = 10; # Display to sleep
      persistent-apps = [
        "/Applications/Microsoft Outlook.app/"
        "/Users/${user}/.nix-profile/Applications/kitty.app/"
        "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/"
        "/Applications/Slack.app/"
        "/System/Applications/Music.app/"
      ];
    };
    trackpad = {
      Clicking = true;
      ActuationStrength = 1;
    };
    NSGlobalDomain = {
      "com.apple.trackpad.scaling" = 1.0;
      "NSAutomaticCapitalizationEnabled" = false;
      "NSAutomaticSpellingCorrectionEnabled" = false;
    };
  };

  users.users.dlutgehet = {
    name = user;
    home = "/Users/${user}";
    shell = pkgs.zsh;
  };

  # SOPS configuration for system-level secrets (currently unused, kept for future use)
  # sops = {
  #   age.sshKeyPaths = [ "/Users/${user}/.ssh/id_ed25519_nixos_key" ];
  #   defaultSopsFile = ../../.sops.yaml;
  #   secrets.github_runner_token = {
  #     sopsFile = ../../secrets/github_runner_token;
  #     format = "binary";
  #     mode = "0400";
  #     owner = user;
  #   };
  # };

  # Create github-runners directory for the user
  system.activationScripts.github-runner-dirs.text = ''
    mkdir -p /Users/${user}/.github-runners/work
    mkdir -p /Users/${user}/.github-runners/_work/work
    chown -R ${user}:staff /Users/${user}/.github-runners
  '';

  # GitHub Actions self-hosted runner (custom launchd, bypasses nix.enable requirement)
  # Using LaunchAgents (user-level) instead of LaunchDaemons (root) because runner refuses to run as root
  # NOTE: Runner must be registered manually first:
  #   cd ~/.github-runners/work
  #   ./config.sh --url https://github.com/SheCrea --token "TOKEN_FROM_GITHUB_UI" --name "dlutgehet-work-macbook" --labels "nix,macos,arm64" --work ~/.github-runners/_work/work
  launchd.user.agents.github-runner-work = {
    script = ''
      set -e
      RUNNER_DIR="$HOME/.github-runners/work"

      # Ensure directory exists
      mkdir -p "$RUNNER_DIR"

      cd "$RUNNER_DIR"

      # Check if runner is configured
      if [ ! -f ".runner" ]; then
        echo "Runner not configured. Please run config.sh manually first."
        echo "See: https://github.com/organizations/SheCrea/settings/actions/runners/new"
        exit 1
      fi

      # Run the runner
      exec ./run.sh
    '';
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/github-runner-work.log";
      StandardErrorPath = "/tmp/github-runner-work.err";
      EnvironmentVariables = {
        HOME = "/Users/${user}";
        PATH = "${
          pkgs.lib.makeBinPath [
            pkgs.git
            pkgs.gh
            pkgs.docker
            pkgs.nodejs
            pkgs.coreutils
            pkgs.curl
            pkgs.jq
          ]
        }:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    };
  };

  # Apply settings on activation.
  # See https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
  system.activationScripts.postActivateSettings.text = ''
    # Following line should allow us to avoid a logout/login cycle
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    killall Dock
  '';

  system.defaults.CustomUserPreferences = {
    "com.apple.CrashReporter" = {
      DialogType = "none";
    };
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
    };
    "com.apple.print.PrintingPrefs" = {
      # Automatically quit printer app once the print jobs complete
      "Quit When Finished" = true;
    };
    "com.apple.SoftwareUpdate" = {
      AutomaticCheckEnabled = true;
      # Check for software updates daily, not just once per week
      ScheduleFrequency = 1;
      # Download newly available updates in background
      AutomaticDownload = 1;
      # Install System data files & security updates
      CriticalUpdateInstall = 1;
    };
    # Prevent Photos from opening automatically when devices are plugged in
    "com.apple.ImageCapture".disableHotPlug = true;
    # Turn on app auto-update
    "com.apple.commerce".AutoUpdate = true;

    # Remove "Do you really want to open?" dialogues
    "com.apple.LaunchServices".LSQuarantine = false;

    "NSGlobalDomain" = {
      # Disable automatic capitalization as it’s annoying when typing code
      NSAutomaticCapitalizationEnabled = false;

      # Disable smart dashes as they’re annoying when typing code
      NSAutomaticDashSubstitutionEnabled = false;

      # Disable automatic period substitution as it’s annoying when typing code
      NSAutomaticPeriodSubstitutionEnabled = false;

      # Disable smart quotes as they’re annoying when typing code
      NSAutomaticQuoteSubstitutionEnabled = false;

      # Disable auto-correct
      NSAutomaticSpellingCorrectionEnabled = false;

      # Enable full keyboard access for all controls
      # (e.g. enable Tab in modal dialogs)
      AppleKeyboardUIMode = 3;

      # Disable press-and-hold for keys in favor of key repeat
      ApplePressAndHoldEnabled = false;

      # Set a blazingly fast keyboard repeat rate
      KeyRepeat = 1;
      InitialKeyRepeat = 30;

      # Enable subpixel font rendering on non-Apple LCDs
      # Reference: https://github.com/kevinSuttle/macOS-Defaults/issues/17#issuecomment-266633501
      AppleFontSmoothing = 1;

      # Finder: show all filename extensions
      AppleShowAllExtensions = true;
    };

    # Require password immediately after sleep or screen saver begins
    "com.apple.screensaver" = {
      askForPassword = 1;
      askForPasswordDelay = 0;
    };

    # Save screenshots to the downloads
    "com.apple.screencapture" = {
      location = "~/Downloads";
      target = "file";
      type = "png";
      disable-shadow = true;
    };

    "com.apple.finder" = {
      # Allow quitting Finder
      QuitMenuItem = true;
      # Finder: show hidden files by default
      AppleShowAllFiles = true;
      ShowStatusBar = true;
      ShowPathbar = true;
      # Display full POSIX path as Finder window title
      _FXShowPosixPathInTitle = true;
      # Use list view in all Finder windows by default
      # Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
      FXPreferredViewStyle = "Nlsv";
      # Disable the warning before emptying the Trash
      WarnOnEmptyTrash = false;
    };

    # Avoid creating .DS_Store files on network or USB volumes
    "com.apple.desktopservices" = {
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };

    # Automatically open a new Finder window when a volume is mounted
    "com.apple.frameworks.diskimages" = {
      auto-open-ro-root = true;
      auto-open-rw-root = true;
      OpenWindowForNewRemovableDisk = true;
    };

    "com.apple.sound.uiaudio" = {
      # Disable UI sounds
      enabled = false;
    };

    # Show bluetooth and sound
    "com.apple.controlcenter" = {
      "NSStatusItem Preferred Position Bluetooth" = 397;
      "NSStatusItem Visible Bluetooth" = 1;
      "NSStatusItem Visible Sound" = 1;
    };
  };
}
// (import ./brew.nix { })
