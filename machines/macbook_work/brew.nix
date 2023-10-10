{ }: {
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    taps = [
      "homebrew/bundle"
      "homebrew/cask"
      "homebrew/cask-fonts"
      "homebrew/core"
    ];
    brews = [ "libiconv" ];
    masApps = {
      "Save to Pocket" = 1477385213;
      "Todoist: To-Do List & Tasks" = 585829637;
      "1Password for Safari" = 1569813296;
    };
    casks = [
      "1password"
      "docker"
      "expressvpn"
      "font-fira-code-nerd-font"
      "font-mplus-nerd-font"
      "google-chrome"
      "microsoft-auto-update"
      "microsoft-office"
      "microsoft-teams"
      "maccy"
      "signal"
      "slack"
      "vlc"
      "zoom"
      "maccy"
    ];
  };
}
