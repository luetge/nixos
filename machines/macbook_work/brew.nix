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
      "azure/azd"
    ];
    brews = [
      "libomp"
      "azd"
      "boost"
      "cmake"
    ];
    masApps = {
      "Todoist: To-Do List & Tasks" = 585829637;
      "1Password for Safari" = 1569813296;
    };
    casks = [
      "1password"
      "blackhole-2ch"
      "docker-desktop"
      "expressvpn"
      "font-m+-nerd-font"
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
      "figma"
      "remarkable"
      "steam"
      "zed"
    ];
  };
}
