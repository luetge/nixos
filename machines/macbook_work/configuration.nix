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

    # Maccy
    "org.p0deje.Maccy" = {
      SUAutomaticallyUpdate = 1;
      SUEnableAutomaticChecks = 1;
      SUHasLaunchedBefore = 1;
      KeyboardShortcuts_popup = ''{"carbonKeyCode":9,"carbonModifiers":768}'';
      searchMode = "fuzzy";
      previewDelay = 300;
      maxMenuItemLength = 75;
      menuIcon = "clipboard";
      ignoredApps = [ "com.1password.1password" ];
      ignoredPasteboardTypes = [
        "Pasteboard generator type"
        "net.antelle.keeweb"
        "de.petermaurer.TransientPasteboardType"
        "com.agilebits.onepassword"
        "com.typeit4me.clipping"
      ];
    };
  };
}
// (import ./brew.nix { })
