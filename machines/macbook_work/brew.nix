{ }:
{
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    taps = [
      "homebrew/bundle"
      "homebrew/cask-fonts"
    ];
    brews = [ ];
    masApps = {
      "Save to Pocket" = 1477385213;
      "Todoist: To-Do List & Tasks" = 585829637;
      "1Password for Safari" = 1569813296;
    };
    casks = [
      "1password"
      "blackhole-2ch"
      "docker"
      "expressvpn"
      "google-chrome"
      "microsoft-auto-update"
      "microsoft-office"
      "microsoft-teams"
      "maccy"
      "signal"
      "slack"
      "vlc"
      "firefox"
      "zoom"
      "maccy"
      "figma"
      "remarkable"
      "steam"
      "zed"
    ];
  };
}
