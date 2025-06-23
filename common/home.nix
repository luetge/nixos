{
  pkgs,
  user,
  isWorkMachine,
  sops-nix,
  config,
  lib,
  noSystemInstall ? false,
  ...
}:

let
  extra_pkgs = import ../overlays/pkgs.nix { inherit pkgs; };
  safe-reattach-to-user-namespace =
    if pkgs.stdenv.isDarwin then
      pkgs.reattach-to-user-namespace
    else
      pkgs.writeShellScriptBin "reattach-to-user-namespace" ''
        exec "$@"
      '';
  compress-pdf = pkgs.writeShellScriptBin "compress-pdf" ''
    set -e
    ${pkgs.ghostscript}/bin/gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.7 -dColorConversionStrategy=/sRGB -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$2" "$1"
  '';
  tweag-nickel = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "tweag";
      name = "vscode-nickel";
      version = "0.5.0";
      hash = "sha256-FmpjscJ/Iq4bmjmMPZypNd1DbsXkNBLXbImrkW+Y5KY=";
    };
  };
  copilot-chat = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "GitHub";
      name = "copilot-chat";
      version = "0.29.2025061302";
      hash = "sha256-6qZTR6IoOko0oVGmlS2DtuupgbW5uK0Fw37ejSKIYIA=";
    };
  };
  user-packages = with pkgs; [
    rsync
    stow
    wget
    zstd
    tldr
    pkg-config
    inetutils
    moreutils
    ack
    coreutils
    # libiconv
    findutils
    openssh
    xz
    ssh-copy-id
    cacert
    openssl
    pcre2
    gettext
    nixfmt-rfc-style
    nixd
    manix
    rage
    safe-reattach-to-user-namespace
    docker
    _1password-cli
    ruff
    pam-reattach
    azure-cli
    signal-export
    pre-commit

    nickel
    nls

    poetry
    poetryPlugins.poetry-plugin-shell
    uv
    rustup
    nodejs
    samply
    pgadmin
    cmake
    yq
    boost.dev

    (python313.withPackages (ps: with ps; [ python-lsp-server ]))
    nerd-fonts.fira-code
    marimo
    nix-output-monitor
    ffmpeg

    devenv

    # Better cli tools
    bat
    eza
    fd
    sd
    tokei
    hyperfine
    grex
    watchexec
    ripgrep

    compress-pdf

    # Fonts
    roboto
    roboto-slab
    roboto-mono
  ];
  homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
  personalFolder = "~/personal/";
  sessionVariables = {
    HISTSIZE = "5000";
    SAVEHIST = "5000";
    EDITOR = "vim";
    LESSCHARSET = "utf-8";
    PAGER = "less -R";
    TERM = "xterm-256color";
    CLICOLOR = "1";
    LC_ALL = "en_US.UTF-8";
    LANG = "en_US.UTF-8";
    LIBRARY_PATH = "${homeDirectory}/.nix-profile/lib";
  };
in
{
  imports = [ sops-nix.homeManagerModules.sops ];
  nixpkgs.config.allowUnfree = true;
  nix = {
    package = lib.mkIf noSystemInstall pkgs.nix;
    extraOptions = ''
      !include ${config.sops.secrets.nix_tokens.path}
    '';
  };
  home = {
    enableNixpkgsReleaseCheck = false;
    username = user;
    homeDirectory = homeDirectory;
    packages = user-packages;
    stateVersion = "21.05";
    file = {
      ".vimrc".source = ../dotfiles/.vimrc;
      ".config/tmux/tmux.remote.conf".source = ../dotfiles/.tmux.remote.conf;
      ".bash_profile".source = ../dotfiles/.bash_profile;
      ".config/zed/settings.json".source = ../dotfiles/zed.json;
      ".ssh/id_ed25519_work.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_work.pub;
      ".ssh/id_ed25519_work_github.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_work_github.pub;
      ".ssh/id_ed25519_personal.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_personal.pub;
      ".ssh/id_ed25519_personal_github.pub".source =
        ../dotfiles/ssh-public-keys/id_ed25519_personal_github.pub;
      ".ssh/id_ed25519_do.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_do.pub;
      ".ssh/id_ed25519_mh.pub".source = ../dotfiles/ssh-public-keys/id_ed25519_mh.pub;
    };
    sessionVariables = sessionVariables;
  };
  fonts.fontconfig.enable = true;

  sops = {
    age.sshKeyPaths = [ "${homeDirectory}/.ssh/id_ed25519_nixos_key" ];
    defaultSopsFile = ../.sops.yaml;
    # Read all files as binary secret files and make them
    # available as config.sops.secrets.`filename`
    secrets =
      let
        toSecret = file: _: {
          sopsFile = ../secrets/${file};
          path = "${homeDirectory}/.config/git/${file}";
          format = "binary";
        };
      in
      pkgs.lib.mapAttrs toSecret (builtins.readDir ../secrets);
  };

  programs = {
    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    kitty = {
      enable = true;
      font = {
        name = "M+1Code Nerd Font Mono";
        size = 18;
      };
      themeFile = "MaterialDark";
      settings = {
        enable_audio_bell = false;
        macos_titlebar_color = "background";
        confirm_os_window_close = 0;
      };
    };
    zsh = {
      enable = true;
      initContent =
        (builtins.readFile ../dotfiles/.zshrc) + "\nexport LIBRARY_PATH=${homeDirectory}/.nix-profile/lib";
      sessionVariables = sessionVariables;
      syntaxHighlighting.enable = true;
      history = {
        extended = true;
        ignoreDups = true;
      };
      plugins = [
        {
          # will source zsh-autosuggestions.plugin.zsh
          name = "zsh-autosuggestions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-autosuggestions";
            rev = "v0.4.0";
            sha256 = "0z6i9wjjklb4lvr7zjhbphibsyx51psv50gm07mbb0kj9058j6kc";
          };
        }
      ];
    };

    home-manager.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = ''rg --files --no-ignore --hidden --follow --glob "!.git/*"'';
      changeDirWidgetOptions = [ "--preview 'tree -C {} | head -200'" ];
      changeDirWidgetCommand = "fd -t d . $HOME/code $HOME/personal/code $HOME/Documents";
      tmux.enableShellIntegration = true;
    };
    dircolors = {
      enable = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      nix-direnv = {
        enable = true;
      };
    };
    htop.enable = true;
    jq.enable = true;
    less.enable = true;

    tmux = {
      enable = true;
      sensibleOnTop = false;
      extraConfig = builtins.readFile ../dotfiles/.tmux.conf;
    };

    vscode =
      let
        extensions = with pkgs.vscode-extensions; [
          usernamehw.errorlens
          ms-python.python
          ms-vscode-remote.remote-ssh
          ms-python.vscode-pylance
          ms-toolsai.jupyter
          ms-toolsai.jupyter-renderers
          tamasfe.even-better-toml
          jnoortheen.nix-ide
          usernamehw.errorlens
          oderwat.indent-rainbow
          copilot-chat
          mkhl.direnv
          rust-lang.rust-analyzer
          tweag-nickel
          github.copilot
          charliermarsh.ruff
          humao.rest-client
          extra_pkgs.ms-toolsai--vscode-ai
          extra_pkgs.ms-toolsai--vscode-ai-remote
          matangover.mypy
          ms-python.black-formatter
          gruntfuggly.todo-tree
          github.vscode-pull-request-github
          # github.remotehub
          github.vscode-github-actions
          esbenp.prettier-vscode
        ];
      in
      {
        enable = true;
        profiles = {
          default = {
            extensions = extensions;
            userSettings = builtins.fromJSON (builtins.readFile ../dotfiles/vscode.json) // {
              "remote.SSH.defaultExtensions" = map (
                ext: "${ext.vscodeExtPublisher}.${ext.vscodeExtName}"
              ) extensions;
            };
          };
          personal = {
            extensions = extensions;
            userSettings = builtins.fromJSON (builtins.readFile ../dotfiles/vscode.json) // {
              "remote.SSH.defaultExtensions" = map (
                ext: "${ext.vscodeExtPublisher}.${ext.vscodeExtName}"
              ) extensions;
            };
          };
        };
        mutableExtensionsDir = false;
      };

    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withNodeJs = false;
      # coc = {
      #   enable = true;
      # };
      extraConfig = builtins.readFile ../dotfiles/.vimrc;
      plugins = with pkgs.vimPlugins; [
        coc-fzf
        fzf-vim
        fugitive
        vim-polyglot
        # coc-nvim
        vim-jsonnet
        vim-hybrid-material
      ];
    };
    ssh = {
      enable = true;
      compression = true;
      forwardAgent = true;
      matchBlocks = {
        # On macOS, add 1password SSH keys
        "*" = {
          extraOptions =
            if pkgs.stdenv.isDarwin then
              { IdentityAgent = "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"; }
            else
              { };
        };
      };
      includes = [ config.sops.secrets.ssh_config.path ];
    };
    git = {
      package = pkgs.gitAndTools.gitFull;
      enable = true;

      includes = [
        {
          path =
            if isWorkMachine then
              config.sops.secrets.gitconfig_work.path
            else
              config.sops.secrets.gitconfig_personal.path;
        }
        {
          condition = "gitdir:${personalFolder}";
          path = config.sops.secrets.gitconfig_personal.path;
        }
      ];

      aliases = {
        l = "log --pretty=oneline -n 20 --graph --abbrev-commit";
        l1 = "log --pretty=oneline -n 1";

        # View the current working tree status using the short format
        s = "status -s";

        # Show the diff between the latest commit and the current state
        d = "!git diff-index --quiet HEAD -- || clear; git --no-pager diff --patch-with-stat";

        # Pull in remote changes for the current repository and all its submodules
        p = "!git pull; git submodule update --remote";

        # Commit all changes
        ca = "!git add -A && git commit -av";

        # Switch to a branch, creating it if necessary
        go = ''!f() { git checkout -b "$1" 2> /dev/null || git checkout "$1"; }; f'';
      };
      lfs.enable = true;
      extraConfig = {
        init = {
          defaultBranch = "main";
        };
        apply = {
          whitespace = "fix";
        };
        commit.gpgsign = true;
        push.autoSetupRemote = true;
        gpg.format = "ssh";
        "gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

        core = {
          # Use custom `.gitignore` and `.gitattributes`
          excludesfile = "~/.gitignore";
          attributesfile = "~/.gitattributes";

          # Treat spaces before tabs and all kinds of trailing whitespace as an error
          # [default] trailing-space: looks for spaces at the end of a line
          # [default] space-before-tab: looks for spaces before tabs at the beginning of a line
          whitespace = "space-before-tab,-indent-with-non-tab,trailing-space";

          # Make `git rebase` safer on OS X
          # More info: <http://www.git-tower.com/blog/make-git-rebase-safe-on-osx/>
          trustctime = "false";

          # Prevent showing files whose names contain non-ASCII symbols as unversioned.
          # http://michael-kuehnel.de/git/2014/11/21/git-mac-osx-and-german-umlaute.html
          precomposeunicode = "false";

          # Special vim mode to alter the vimrc loading behavior, i.e. no long loading plugins
          editor = "GIT=1 vim";
          ignorecase = "true";
        };
        color = {
          # Use colors in Git commands that are capable of colored output when
          # outputting to the terminal. (This is the default setting in Git ≥ 1.8.4.)
          ui = "auto";
        };
        "color \"branch\"" = {
          current = "yellow reverse";
          local = "yellow";
          remote = "green";
        };
        "color \"diff\"" = {
          meta = "yellow bold";
          frag = "magenta bold";
          old = "red";
          new = "green";
        };
        "color \"status\"" = {
          added = "yellow";
          changed = "green";
          untracked = "cyan";
        };
        diff = {
          # Detect copies as well as renames
          renames = "copies";
        };
        help = {
          autocorrect = "1";
        };
        merge = {
          # Include summaries of merged commits in newly created merge commit messages
          log = "true";
        };
        push = {
          default = "matching";
          followTags = "true";
        };
        pull = {
          rebase = "true";
          ff = "only";
        };
      };
    };
  };
}
